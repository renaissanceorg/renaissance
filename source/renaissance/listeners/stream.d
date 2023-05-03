module renaissance.listeners.stream;

import renaissance.listeners;

import renaissance.server;
import std.socket;
import river.core;
import river.impls.sock : SockStream;
import core.thread;
import renaissance.connection;
import renaissance.logging;

public class StreamListener : Listener
{
    /** 
     * Address to bind and listen for
     * connections on
     */
    private Address bindAddr;

    /** 
     * The server socket to listen for
     * incoming connections on
     */
    private Socket servSock;

    /** 
     * The connetion loop thread
     */
    private Thread workerThread;

    /** 
     * Whether or not we are running
     *
     * TODO: Look into making volatile for caching issues
     */
    private bool isRunning = false;

    private this(Server server, Address bindAddr)
    {
        super(server);

        /* Save the binding information */
        this.bindAddr = bindAddr;

        /* Create the socket */
        servSock = new Socket(bindAddr.addressFamily(), SocketType.STREAM);

        /* When started, the thread should run the connectionLoop() */
        workerThread = new Thread(&connectionLoop);
    }

    private void connectionLoop()
    {
        while(isRunning)
        {
            Socket clientSocket = servSock.accept();
            logger.info("New incoming connection on listener '"~this.toString()~"' from '"~clientSocket.toString()~"'");

            /** 
             * Create a `SockStream` from the `Socket`,
             * a new connection handler with the stream
             * (doing so starts the connection handler on
             * its own thread
             */
            Stream clientStream = new SockStream(clientSocket);
            Connection clientConnection = Connection.newConnection(server, clientStream);
        }
    }

    public override void startListener()
    {
        try
        {
            servSock.bind(bindAddr);
        }
        catch(SocketOSException sockErr)
        {
            throw new ListenerException("Could not bind listener to address '"~bindAddr.toString()~"'");
        }

        try
        {
            servSock.listen(0); // TODO: Make this configurable, the queueing limit (currently unlimited)
        }
        catch(SocketOSException sockErr)
        {
            throw new ListenerException("Could not listen on socket '"~servSock.toString()~"'");
        }

        /* Set state to running */
        isRunning = true;

        /* Start the worker thread */
        workerThread.start();
    }

    // TODO: Look into not allowing it to run again, or maybe not, allow re-run
    public override void stopListener()
    {
        /* Set running status to false */
        isRunning = false;

        /* Close the server socket, unblocking any `accept()` call */
        servSock.close();
    }

    public static StreamListener create(Server server, Address bindAddress)
    {
        StreamListener streamListener = new StreamListener(server, bindAddress);

        // TODO: Set bind address here
        


        return streamListener;
    }
}