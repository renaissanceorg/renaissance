module renaissance.listeners.stream;

import renaissance.listeners;

import renaissance.server;
import std.socket;
import river.core;
import river.impls.sock : SockStream;
import core.thread;
import renaissance.connection;
import renaissance.logging;
import core.sync.mutex : Mutex;
import core.sync.condition : Condition;

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

    private Mutex backoffMutex;
    private Condition backoffCond;

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

        /* Initialize the backoff facilities */
        this.backoffMutex = new Mutex();
        this.backoffCond = new Condition(this.backoffMutex);
    }

    Duration backoffDuration = dur!("seconds")(1);

    private void connectionLoop()
    {
        while(isRunning)
        {
            Socket clientSocket;

            try
            {
                clientSocket = servSock.accept();
                logger.info("New incoming connection on listener '"~this.toString()~"' from '"~clientSocket.toString()~"'");
            }
            catch(SocketAcceptException e)
            {
                logger.error("There was an error accepting the socket:", e);

                // TODO: Handling accept (which creates a new socket pair) is a problem
                // ... we must code a backoff in hopes some client disconnects freeing
                // ... up space for a new fd pair to be created
                logger.warn("Waiting ", this.backoffDuration, " many seconds before retrying...");
                backoff();
                logger.warn("Retrying the accept");
                continue;
            }

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

    private void backoff()
    {
        // Lock the mutex
        this.backoffMutex.lock();

        // Wait on the condition for `backoffDuration`-many duration
        this.backoffCond.wait(this.backoffDuration);
        
        // Unlock the mutex
        this.backoffMutex.unlock();
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

    /** 
     * Wakes up the sleeping
     * backoff sleeper which
     * may have been activated
     * in the case the `accept()`
     * call was failing
     */
    public override void nudge()
    {
        // Lock the mutex
        this.backoffMutex.lock();

        // Wake up any sleeper (only one possible)
        this.backoffCond.notify();

        // Unlock the mutex
        this.backoffMutex.unlock();
    }

    public static StreamListener create(Server server, Address bindAddress)
    {
        StreamListener streamListener = new StreamListener(server, bindAddress);

        // TODO: Set bind address here
        


        return streamListener;
    }
}