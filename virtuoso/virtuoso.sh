#!/bin/sh

prefix=/opt/virtuoso
port=1111
user=dba
pass=dba
isql="${prefix}/bin/isql ${port} $user $pass"

case "$1" in
  start)
        (cd ${prefix}/var/lib/virtuoso/db; ${prefix}/bin/virtuoso-t)
        ;;
  stop)
        echo "shutdown;" | $isql
        ;;
  status)
        echo "isql ${port}"
        echo "status();" | $isql
        echo
        ;;
  watch)
        echo "select count(*) from DB.DBA.LOAD_LIST where ll_state = 0;" | $isql
        ;;
  isql)
        $isql
        ;;
  port)
        echo ${port}
        ;;
  path)
        echo ${prefix}/var/lib/virtuoso/db/
        ;;
  list)
        ls -l ${prefix}/var/lib/virtuoso/db/
        ;;
  log)
        tail -f ${prefix}/var/lib/virtuoso/db/virtuoso.log
        ;;
  edit)
        ${EDITOR:-vi} ${prefix}/var/lib/virtuoso/db/virtuoso.ini
        ;;
  clear)
        mv ${prefix}/var/lib/virtuoso/db/virtuoso.ini ${prefix}/virtuoso.ini
        rm -f ${prefix}/var/lib/virtuoso/db/*
        mv ${prefix}/virtuoso.ini ${prefix}/var/lib/virtuoso/db/virtuoso.ini
        ;;
  loadrdf)
	echo "log_enable(2, 1);" | $isql
	echo "DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('$2'), '', '$3');" | $isql
	echo "checkpoint;" | $isql
        ;;
  loadttl)
	echo "log_enable(2, 1);" | $isql
	echo "DB.DBA.TTLP_MT(file_to_string_output('$2'), '', '$3', 81);" | $isql
	echo "checkpoint;" | $isql
        ;;
  loaddir)
	echo "log_enable(2, 1);" | $isql
	echo "ld_dir_all('$2', '$3', '$4');" | $isql
	echo "rdf_loader_run();" | $isql
	echo "checkpoint;" | $isql
        ;;
  *)
        echo "Usage: $0 {start|stop|status|watch|isql|port|path|list|log|edit|clear|loadrdf|loadttl|loaddir}"
        echo "       $0 loadrdf file.rdf graph_uri"
        echo "       $0 loadttl file.ttl graph_uri"
        echo "       $0 loaddir dir pattern graph_uri"
        exit 2
esac
