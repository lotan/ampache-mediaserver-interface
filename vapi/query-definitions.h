#ifndef _QUERY_DEFINITIONS_
#define _QUERY_DEFINITIONS_

/* the number of the following objects are such that
 * integer types are grouped and strings types are grouped
 * for easier querying */

/* org.gnome.MediaObject2 */
static int const PROPPARENT        = 31; /* first o */
static int const PROPTYPE          = 41; /* first s */
static int const PROPPATH          = 32;
static int const PROPDISPLAYNAME   = 42;

/* org.gnome.MediaItem2 */
static int const PROPURLS          = 51; /* first a */
static int const PROPMIMETYPE      = 43;
static int const PROPSIZE          = 1;  /* first x */
static int const PROPARTIST        = 44;
static int const PROPALBUM         = 45;
static int const PROPDATE          = 46;
static int const PROPGENRE         = 47;
static int const PROPDLNAPROFILE   = 48;
/* video and audio/music */
static int const PROPDURATION      = 11; /* first i */
static int const PROPBITRATE       = 12;
static int const PROPSAMPLERATE    = 13;
static int const PROPBITSPERSAMPLE = 14;
/* video and images */
static int const PROPWIDTH         = 15;
static int const PROPHEIGHT        = 16;
static int const PROPCOLORDEPTH    = 17;
static int const PROPPIXELWIDTH    = 18;
static int const PROPPIXELHEIGHT   = 19;
static int const PROPTHUMBNAIL     = 33;
/* audio and music */
static int const PROPALBUMART      = 34;
/* music */
static int const PROPTRACKNUMBER   = 20;

static const char * const PROPERTIES[] = {"",
                                          "Size",
                                          "", "", "", "", "", "", "", "", "",
                                          "Duration",
                                          "Bitrate",
                                          "SampleRate",
                                          "BitsPerSample",
                                          "Width",
                                          "Height",
                                          "ColorDepth",
                                          "PixelWidth",
                                          "PixelHeight",
                                          "TrackNumber",
                                          "", "", "", "", "", "", "", "", "", "",
                                          "Parent",
                                          "Path",
                                          "Thumbnail",
                                          "AlbumArt",
					  "", "", "", "", "", "",
                                          "Type",
                                          "DisplayName",
                                          "MIMEType",
                                          "Artist",
                                          "Album",
                                          "Date",
                                          "Genre",
                                          "DLNAProfile",
                                          "", "",
                                          "URLs"};

static const int FILTER[][52] = {{0, /* MediaItem */
                                  1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                  1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                  1, 1, 1, 1, 0, 0, 0, 0, 0, 0,
                                  1, 1, 1, 1, 1, 1, 1, 0, 0, 0,
                                  1},
                                 {0, /* MediaContainer */
                                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                  1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
                                  1, 1, 0, 0, 0, 0, 0, 0, 0, 0,
                                  0}};

#endif /* _QUERY_DEFINITIONS_ */
