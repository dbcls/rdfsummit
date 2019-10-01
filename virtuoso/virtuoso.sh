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
        read -p "Deleate all data. Continue? (Yes/No): " answer
        if [ "${answer:-No}" = "Yes" ]; then
          mv ${prefix}/var/lib/virtuoso/db/virtuoso.ini ${prefix}/virtuoso.ini
          rm -f ${prefix}/var/lib/virtuoso/db/*
          mv ${prefix}/virtuoso.ini ${prefix}/var/lib/virtuoso/db/virtuoso.ini
        else
          echo "Aborted."
        fi
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
          DB.DBA.TTLP_MT(file_to_string_output('$3'), '', '$2', 337);
          checkpoint;
        " | ${isql}
        ;;
    loaddir)
        echo "
          log_enable(2,1);
          ld_dir_all('$3', '$4', '$2');
          rdf_loader_run();
          checkpoint;
        " | ${isql}
        ;;
    addloader)
        echo "rdf_loader_run();" | ${isql} &
        ;;
    watch)
        echo "SELECT \
                CASE ll_state \
                  WHEN 0 THEN 'Waiting' \
                  WHEN 1 THEN 'Loading' \
                  WHEN 2 THEN 'Done' \
                  ELSE 'Unknown' \
                END AS status, \
                COUNT(*) \
                FROM DB.DBA.LOAD_LIST \
                GROUP BY ll_state;" | ${isql}
        ;;
    watch_wait)
        echo "SELECT ll_graph, ll_file \
          FROM DB.DBA.LOAD_LIST WHERE ll_state = 0;" \
            | ${isql} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_load)
        echo "SELECT ll_graph, ll_file, ll_started \
          FROM DB.DBA.LOAD_LIST WHERE ll_state = 1;" \
            | ${isql} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_done)
        echo "SELECT ll_graph, ll_file, ll_started, (ll_done - ll_started) AS duration \
          FROM DB.DBA.LOAD_LIST WHERE ll_state = 2;" \
            | ${isql} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_error)
        echo "SELECT ll_graph, ll_file, ll_started, (ll_done - ll_started) AS duration, ll_error \
          FROM DB.DBA.LOAD_LIST WHERE ll_error IS NOT NULL;" \
            | ${isql} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    list)
        echo "SPARQL SELECT ?g WHERE { GRAPH ?g {?s ?p ?o} } GROUP BY ?g;" | ${isql}
        ;;
    head)
        echo "SPARQL SELECT DISTINCT * WHERE { GRAPH <$2> {?s ?p ?o} } LIMIT 10;" | ${isql}
        ;;
    drop)
        read -p "Deleate all data in the graph '$2'. Continue? (Yes/No): " answer
        if [ "${answer:-No}" = "Yes" ]; then
          echo "
            log_enable(2,1);
            SPARQL CLEAR GRAPH <$2>;
            checkpoint;
          " | ${isql}
          echo "SPARQL SELECT COUNT(*) FROM <$2> WHERE {?s ?p ?o};" | ${isql}
          echo "DELETE FROM DB.DBA.LOAD_LIST WHERE ll_graph = '$2';" | ${isql}
        else
          echo "Aborted."
        fi
        ;;
    help)
        echo "Usage:"
        echo "  Show this help"
        echo "    $0 help"
        echo "  Start the virtuoso server"
        echo "    $0 start"
        echo "  Stop the virtuoso server"
        echo "    $0 stop"
        echo "  Show the status of the server"
        echo "    $0 status"
        echo "  Invoke the isql command"
        echo "    $0 isql"
        echo "  Show a port number of the server"
        echo "    $0 port"
        echo "  Show a path to the data directory"
        echo "    $0 path"
        echo "  Show directory contents of the data directory"
        echo "    $0 dir"
        echo "  Show a log file of the server"
        echo "    $0 log"
        echo "  Edit a config file of the server"
        echo "    $0 edit"
        echo
        echo "  Load RDF files"
        echo "    $0 loadrdf 'http://example.org/graph_uri' /path/to/file.rdf"
        echo "    $0 loadttl 'http://example.org/graph_uri' /path/to/file.ttl"
        echo "    $0 loaddir 'http://example.org/graph_uri' /path/to/directory glob_pattern"
        echo "      (where glob_pattern can be something like '*.ttl' or '*.rdf')"
        echo "  Count remaining files to be loaded"
        echo "    $0 watch"
        echo "  List file names to be loaded, being loaded, and finished loading"
        echo "    $0 watch_wait"
        echo "    $0 watch_load"
        echo "    $0 watch_done"
        echo "  List file names with loading errors"
        echo "    $0 watch_error"
        echo "  Add an extra loading process"
        echo "    $0 addloader"
        echo
        echo "  List graphs"
        echo "    $0 list"
        echo "  Peek a graph"
        echo "    $0 head 'http://example.org/graph_uri'"
        echo "  Drop a graph"
        echo "    $0 drop 'http://example.org/graph_uri'"
        echo
        echo "  Delete entire data (except for a config file)"
        echo "    $0 clear"
        exit 2
        ;;
    *)
        echo "Usage:"
        echo "$0 help"
        echo "$0 {start|stop|status|isql|port|path|dir|log|edit|clear}"
        echo "$0 {loadrdf|loadttl} 'http://example.org/graph_uri' /path/to/file"
        echo "$0 {loaddir} 'http://example.org/graph_uri' /path/to/directory '*.(ttl|rdf|owl)'"
        echo "$0 {addloader|watch|watch_wait|watch_load|watch_done|watch_error}"
        echo "$0 {list|head|drop} [graph_uri]"
        exit 2
esac

