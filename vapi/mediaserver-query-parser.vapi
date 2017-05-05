namespace mediaserverQueryParser {
    [CCode (cname = "parse_mediaserver_query", cheader_filename = "mediaserver-query-parser.h")]	
    public static string? parse_mediaserver_query(string query, int filter);
}
