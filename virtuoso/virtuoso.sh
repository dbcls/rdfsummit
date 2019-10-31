#!/bin/sh

### Parameters to be redefined

port=1111
user=dba
pass=dba

## Default for the source code distribution

prefix=/opt/virtuoso
dbdir="${prefix}/var/lib/virtuoso/db"
dbfile="virtuoso"

## Parameters for binary packages

# Download from (as of release v7.2.5.1)
#   * https://github.com/openlink/virtuoso-opensource/releases
# Linux
#   * virtuoso-opensource.x86_64-generic_glibc25-linux-gnu.tar.gz
# Mac OS X (macOS)
#   * virtuoso-opensource-7.2.5-macosx-app.dmg
# Windows
#   * Virtuoso_OpenSource_Server_7.20.x64.exe

# To use the Virtuoso Linux binary package, set the installed application directory to ${prefix}.

#prefix=/opt/virtuoso-opensource
#dbdir="${prefix}/database"
#dbfile="virtuoso"

# To use the Virtuoso OS X binary package, set the installed application directory to ${prefix}.

#prefix="/Applications/Virtuoso Open Source Edition v7.2.app/Contents/virtuoso-opensource"
#dbdir="${prefix}/database"
#dbfile="database"

# To use the Virtuoso Windows binary package, set the installed application directory to ${prefix} and enable ${ext}.

#prefix="/mnt/c/Program Files/OpenLink Software/Virtuoso OpenSource 7.20/"
#dbdir="${prefix}/database"
#dbfile="virtuoso"
#ext=".exe"

### End of parameters


isql="${prefix}/bin/isql${ext}"
opts="${port} ${user} ${pass}"

case $1 in
    start)
        (cd "${dbdir}"; "${prefix}/bin/virtuoso-t${ext}")
        ;;
    stop)
        echo "shutdown;" | "${isql}" ${opts}
        ;;
    status)
        echo "isql ${port}"
        echo "status();" | "${isql}" ${opts}
        echo
        ;;
    isql)
        "${isql}" ${opts}
        ;;
    port)
        echo "${port}"
        ;;
    path)
        echo "${dbdir}"
        ;;
    dir)
        ls -l "${dbdir}"
        ;;
    log)
        tail -f "${dbdir}/${dbfile}.log"
        ;;
    edit)
        ${EDITOR:-vi} "${dbdir}/virtuoso.ini"
        ;;
    delete)
        read -p "Deleate all data. Continue? (Yes/No): " answer
        if [ "${answer:-No}" = "Yes" ]; then
          mv "${dbdir}/virtuoso.ini" "${prefix}/virtuoso.ini"
          rm -f "${dbdir}"/*
          mv "${prefix}/virtuoso.ini" "${dbdir}/virtuoso.ini"
        else
          echo "Aborted."
        fi
        ;;
    loadrdf)
        echo "
          log_enable(2,1);
          DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('$3'), '', '$2');
          checkpoint;
        " | "${isql}" ${opts}
        ;;
    loadttl)
        echo "
          log_enable(2,1);
          DB.DBA.TTLP_MT(file_to_string_output('$3'), '', '$2', 337);
          checkpoint;
        " | "${isql}" ${opts}
        ;;
    loaddir)
        echo "
          log_enable(2,1);
          ld_dir_all('$3', '$4', '$2');
          rdf_loader_run();
          checkpoint;
        " | "${isql}" ${opts}
        ;;
    addloader)
        echo "rdf_loader_run();" | "${isql}" ${opts} &
        ;;
    watch)
        echo "
          SELECT \
            CASE ll_state \
              WHEN 0 THEN 'Waiting' \
              WHEN 1 THEN 'Loading' \
              WHEN 2 THEN 'Done' \
              ELSE 'Unknown' \
            END AS status, \
            COUNT(*) AS files \
          FROM DB.DBA.LOAD_LIST \
          GROUP BY ll_state \
          ORDER BY status;
        " | "${isql}" ${opts}
        ;;
    watch_wait)
        echo "
          SELECT ll_graph, ll_file \
          FROM DB.DBA.LOAD_LIST \
          WHERE ll_state = 0;
        " | "${isql}" ${opts} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_load)
        echo "
          SELECT ll_graph, ll_file, ll_started \
          FROM DB.DBA.LOAD_LIST \
          WHERE ll_state = 1;
        " | "${isql}" ${opts} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_done)
        echo "
          SELECT ll_graph, ll_file, ll_started, (ll_done - ll_started) AS duration \
          FROM DB.DBA.LOAD_LIST \
          WHERE ll_state = 2;
        " | "${isql}" ${opts} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    watch_error)
        echo "
          SELECT ll_graph, ll_file, ll_started, (ll_done - ll_started) AS duration, ll_error \
          FROM DB.DBA.LOAD_LIST \
          WHERE ll_error IS NOT NULL;
        " | "${isql}" ${opts} | perl -ne 's/  +/\t/g; print if /^(SQL> ll|http)/#'
        ;;
    list)
        echo "SELECT * FROM SPARQL_SELECT_KNOWN_GRAPHS_T ORDER BY GRAPH_IRI;" | "${isql}" ${opts}
        ;;
    head)
        echo "SPARQL SELECT DISTINCT * WHERE { GRAPH <$2> {?s ?p ?o} } LIMIT 10;" | "${isql}" ${opts}
        ;;
    drop)
        read -p "Deleate all data in the graph '$2'. Continue? (Yes/No): " answer
        if [ "${answer:-No}" = "Yes" ]; then
          echo "
            log_enable(2,1);
            SPARQL CLEAR GRAPH <$2>;
            checkpoint;
          " | "${isql}" ${opts}
          echo "SPARQL SELECT COUNT(*) FROM <$2> WHERE {?s ?p ?o};" | "${isql}" ${opts}
          echo "DELETE FROM DB.DBA.LOAD_LIST WHERE ll_graph = '$2';" | "${isql}" ${opts}
        else
          echo "Aborted."
        fi
        ;;
    query)
        echo "SPARQL $2 ;" | "${isql}" ${opts}
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
        echo "    $0 delete"
        echo
        echo "  Execute a SPARQL query via the isql command"
        echo "    $0 query 'select * where {?your ?sparql ?query.} limit 100'"
        echo
        exit 2
        ;;
    *)
        echo "Usage:"
        echo "$0 help"
        echo "$0 {start|stop|status|isql|port|path|dir|log|edit|delete}"
        echo "$0 {loadrdf|loadttl} 'http://example.org/graph_uri' /path/to/file"
        echo "$0 {loaddir} 'http://example.org/graph_uri' /path/to/directory '*.(ttl|rdf|owl)'"
        echo "$0 {addloader|watch|watch_wait|watch_load|watch_done|watch_error}"
        echo "$0 {list|head|drop} [graph_uri]"
        echo "$0 query 'select * where {?your ?sparql ?query.} limit 100'"
        exit 2
esac

