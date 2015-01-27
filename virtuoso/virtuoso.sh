#!/bin/sh

prefix=/opt/virtuoso
port=1111
user=dba
pass=dba

isql="${prefix}/bin/isql ${port} ${user} ${pass}"

case $1 in
    start)
        (cd ${prefix}/var/lib/virtuoso/db; ${prefix}/bin/virtuoso-t)
        ;;
    stop)
        echo "shutdown;" | ${isql}
        ;;
    status)
        echo "isql ${port}"
        echo "status();" | ${isql}
        echo
        ;;
    isql)
        ${isql}
        ;;
    port)
        echo ${port}
        ;;
    path)
        echo ${prefix}/var/lib/virtuoso/db/
        ;;
    dir)
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
        echo "
          log_enable(2,1);
          DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('$3'), '', '$2');
          checkpoint;
        " | ${isql}
        ;;
    loadttl)
        echo "
          log_enable(2,1);
          DB.DBA.TTLP_MT(file_to_string_output('$3'), '', '$2', 81);
          checkpoint;
        " | ${isql}
        ;;
    loaddir)
        echo "
          log_enable(2,1);
          ld_dir_all('$4', '$2', '$3');
          rdf_loader_run();
          checkpoint;
        " | ${isql}
        ;;
    watch)
        echo 'select count(*) from DB.DBA.LOAD_LIST where ll_state = 0;' | ${isql}
        ;;
    list)
        echo "SPARQL SELECT DISTINCT ?g WHERE { GRAPH ?g {?s ?p ?o} };" | ${isql}
        ;;
    head)
        echo "SPARQL SELECT DISTINCT * WHERE { GRAPH <$2> {?s ?p ?o} } LIMIT 10;" | ${isql}
        ;;
    drop)
        echo "
          log_enable(2,1);
          SPARQL CLEAR GRAPH <$2>;
          checkpoint;
        " | $isql
        echo "SPARQL SELECT COUNT(*) FROM <$2> WHERE {?s ?p ?o};" | $isql
        echo "DELETE FROM DB.DBA.LOAD_LIST WHERE ll_graph = '$2';" | $isql
        echo "SPARQL DROP GRAPH <$2>;" | $isql
        ;;
    help)
        echo "Usage:"
        echo "  Show this help"
        echo "    $0 help"
        echo "  Start the virtuoso server"
        echo "    $0 start"
        echo "  Stop the virtuoso server"
        echo "    $0 stop"
        echo "  Show status of the server"
        echo "    $0 status"
        echo "  Invoke an isql command"
        echo "    $0 isql"
        echo "  Show a port number of the server"
        echo "    $0 port"
        echo "  Show a path to the data directory"
        echo "    $0 path"
        echo "  Show directory contents of data directory"
        echo "    $0 dir"
        echo "  Show a log file of the server"
        echo "    $0 log"
        echo "  Edit a config file of the server"
        echo "    $0 edit"
        echo
        echo "  Loading RDF files"
        echo "    $0 loadrdf graph_uri file.rdf"
        echo "    $0 loadttl graph_uri file.ttl"
        echo "    $0 loaddir graph_uri dir pattern"
        echo "  Count remaining files to be loaded"
        echo "    $0 watch"
        echo "  Peek a graph"
        echo "    $0 head graph_uri"
        echo "  Drop a graph"
        echo "    $0 drop graph_uri"
        echo "  List graphs"
        echo "    $0 list"
        echo
        echo "  Delete entire data (except for a config file)"
        echo "    $0 clear"
        exit 2
	;;
    *)
	echo "Usage:"
        echo "$0 help"
        echo "$0 {start|stop|status|isql|port|path|dir|log|edit|clear}"
        echo "$0 {loadrdf|loadttl|loaddir|watch|list|head|drop} [graph_uri [file|dir pattern]]"
        exit 2
esac
