#--------------------------------------------------------------------------------
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#--------------------------------------------------------------------------------
#
# Makefile for MRQL
# Requires: jflex  (it can be installed as a Linux package)
#
#--------------------------------------------------------------------------------

MRQL_HOME=$(shell readlink -f .)

include conf/mrql-env.sh

export CLASSPATH=${MRQL_CLASSPATH}:${CUP_JAR}:lib/gen.jar:lib/jline-1.0.jar
export JAVA_HOME

JAVAC = ${JAVA_HOME}/bin/javac -g:none -d classes
JAVA = ${JAVA_HOME}/bin/java
JAR = ${JAVA_HOME}/bin/jar
JFLEX = jflex --quiet --nobak
CUP = ${JAVA} -jar ${CUP_JAR} -nosummary
GEN = ${JAVA} Gen.Main

sources := src/*.java
mr_sources := ${sources} src/MapReduce/*.java
bsp_sources := ${sources} src/BSP/*.java


all: common
	@${GEN} src/MapReduce/*.gen -o tmp
	@${JAVAC} ${mr_sources} tmp/*.java
	@${JAR} cf lib/mrql.jar -C classes/ .

bsp: common
	@${GEN} src/BSP/*.gen -o tmp
	@${JAVAC} ${bsp_sources} tmp/*.java
	@${JAR} cf lib/mrql-bsp.jar -C classes/ .

common: clean_build mrql_parser json_parser
	@cd classes; ${JAR} xf ../lib/gen.jar; ${JAR} xf ${CUP_JAR}; ${JAR} xf ../lib/jline-1.0.jar; cd ..
	@${GEN} src/*.gen -o tmp

clean_build:
	@rm -rf classes tmp
	@mkdir -p classes tmp tests/results tests/results/memory tests/results/hadoop tests/results/bsp

mrql_parser:
	@${JFLEX} src/mrql.lex -d tmp
	@${GEN} src/mrql.cgen -o tmp/mrql.cup
	@${CUP} -parser MRQLParser tmp/mrql.cup
	@mv sym.java MRQLParser.java tmp/

json_parser:
	@${JFLEX} src/JSON.lex -d tmp
	@${CUP} -parser JSONParser -symbols jsym src/JSON.cup
	@mv jsym.java JSONParser.java tmp/

validate: validate_hadoop validate_hama

validate_hadoop:
	@echo "Evaluating test queries in memory (Map-Reduce mode):"
	@${JAVA} -ms256m -mx1024m -classpath ${MRQL_HOME}/lib/mrql.jar:${MRQL_CLASSPATH} org.apache.mrql.Test tests/queries tests/results/memory tests/error_log.txt
	@echo "Evaluating test queries in Hadoop local mode:"
	@${HADOOP_HOME}/bin/hadoop --config conf jar ${MRQL_HOME}/lib/mrql.jar org.apache.mrql.Test -local tests/queries tests/results/hadoop tests/error_log.txt 2>/dev/null

validate_hama:
	@echo "Evaluating test queries in memory (BSP mode):"
	@${JAVA} -ms256m -mx1024m -classpath ${MRQL_HOME}/lib/mrql-bsp.jar:${MRQL_CLASSPATH} org.apache.mrql.Test tests/queries tests/results/memory tests/error_log.txt
	@echo "Evaluating test queries in Hama local mode:"
	@${HAMA_HOME}/bin/hama --config conf-hama jar ${MRQL_HOME}/lib/mrql-bsp.jar org.apache.mrql.Test -local tests/queries tests/results/bsp tests/error_log.txt 2>/dev/null

javadoc: all
	@${JAVA_HOME}/bin/javadoc ${mr_sources} tmp/*.java -d /tmp/web-mrql

clean_tests:
	@/bin/rm -rf tests/results/*/*

clean: 
	@/bin/rm -rf *~ */*~ */*/*~ classes mrql-tmp tmp tests/error_log.txt
