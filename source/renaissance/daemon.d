module renaissance.daemon;

import renaissance.logging;

import std.stdio;
import river.core;
import river.impls.file : FileStream;
import std.json;

void main()
{
    logger.info("Starting renaissance...");

    // TODO: Add command-line parsing here, using jcli
    // JSONValue config = getConfig("renaissance.json");

    import renaissance.server;
    Server server = new Server();

    import renaissance.listeners;
    import std.socket;
    // Address listenAddr = parseAddress("::1", 9091);
    Address listenAddr = new UnixAddress("/tmp/renaissance.sock");
    StreamListener streamListener = StreamListener.create(server, listenAddr);

    server.start();
}

JSONValue getConfig(string configPath)
{
    File configFile;
    configFile.open(configPath);

    // TODO: Wait for FileSTream from river-streams package to become
    // ... available
    Stream fileStream = new FileStream(configFile);

    byte[] fileData;
    logger.dbg("Before calling size(): ", configFile.tell());
    fileData.length =configFile.size(); //FIXME: THis seems to seek it ahead and not return it ?
    logger.dbg("AFTER calling size(): ", configFile.tell());
    configFile.rewind();
    logger.dbg("File size: ", fileData.length);


    // NOTE: Throws a StreamException on error
    fileStream.readFully(fileData);

    logger.dbg(fileData);


    JSONValue json = parseJSON("");

    return json;
}