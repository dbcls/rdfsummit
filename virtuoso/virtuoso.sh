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
    isql)
        $isql
        ;;
    port)
        echo ${port}
        ;;
    path)
        echo ${prefix}/var/lib/virtuoso/db/
        ;;
    ls)
        ls -l ${prefix}/var/lib/virtuoso/db/
        ;;
    log)
        tail -f ${prefix}/var/lib/virtuoso/db/virtuoso.log
        ;;
    edit)
        ${EDITOR:-vi} ${prefix}/var/lib/virtuoso/db/virtuoso.ini
        ;;
    loadrdf)
        echo "
          log_enable(2,1);
          DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('$2'), '', '$3');
          checkpoint;
        " | $isql
        ;;
    loadttl)
        echo "
          log_enable(2,1);
          DB.DBA.TTLP_MT(file_to_string_output('$2'), '', '$3', 81);
          checkpoint;
        " | $isql
        ;;
    loaddir)
        echo "
          log_enable(2,1);
          ld_dir_all('$2', '$3', '$4');
          rdf_loader_run();
          checkpoint;
        " | $isql
        ;;
    watch)
        echo "SELECT COUNT(*) FROM DB.DBA.LOAD_LIST WHERE ll_state = 0;" | $isql
        ;;
    list)
        echo "SPARQL SELECT DISTINCT ?g WHERE { GRAPH ?g {?s ?p ?o} };" | $isql
        ;;
    head)
        echo "SPARQL SELECT DISTINCT * WHERE { GRAPH <$2> {?s ?p ?o} } LIMIT 10;" | $isql
        ;;
    clear)
        echo "
          log_enable(2,1);
          SPARQL CLEAR GRAPH <$2>;
          checkpoint;
        " | $isql
        echo "SPARQL SELECT COUNT(*) FROM <$2> WHERE {?s ?p ?o};" | $isql
        echo "DELETE FROM DB.DBA.LOAD_LIST WHERE ll_graph = '$2';" | $isql
        echo "SPARQL DROP GRAPH <$2>;" | $isql
        ;;
    remove)
        mv ${prefix}/var/lib/virtuoso/db/virtuoso.ini ${prefix}/virtuoso.ini
        rm -f ${prefix}/var/lib/virtuoso/db/*
        mv ${prefix}/virtuoso.ini ${prefix}/var/lib/virtuoso/db/virtuoso.ini
        ;;
    *)
        echo "Usage:"
        echo "  Start/stop/config a Virtuoso server"
        echo "    $0 {start|stop|status|isql|port|path|ls|log|edit}"
        echo "  Loading RDF files"
        echo "    $0 loadrdf file.rdf graph_uri"
        echo "    $0 loadttl file.ttl graph_uri"
        echo "    $0 loaddir dir pattern graph_uri"
        echo "  Count remaining files"
        echo "    $0 watch"
        echo "  List graphs"
        echo "    $0 list"
        echo "  Peek a graph"
        echo "    $0 head graph_uri"
        echo "  Clear a graph"
        echo "    $0 clear graph_uri"
        echo "  Remove entire database"
        echo "    $0 remove"
        exit 2
esac
