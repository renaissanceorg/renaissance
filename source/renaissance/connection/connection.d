module renaissance.connection.connection;

import davinci;
import core.thread : Thread;
import renaissance.server;
import river.core;
import tristanable;
import renaissance.daemon : logger;

public class Connection : Thread
{
    /** 
     * Associated server instance
     */
    private Server associatedServer;

    /** 
     * Underlying stream connecting us to
     * the client
     */
    private Stream clientStream;

    // TODO: TRistanable manager here
    private Manager tManager;
    private Queue incomingQueue;

    private this(Server associatedServer, Stream clientStream)
    {
        this.associatedServer = associatedServer;
        this.clientStream = clientStream;

        // TODO: Setup the tristanable manager here
        this.tManager = new Manager(clientStream);

        // TODO: If we not using tasky, probably not, then
        // ... register some queues here or use all
        // ... we need access ti akk so maybe
        // ... when the queue listener support drops
        //
        // UPDATE: Use the throwaway queue method
        initTManager();

        /* Set the worker function for the thread */
        super(&worker);
    }

    private void initTManager()
    {
        /* Create a Queue (doesn't matter its ID) */
        this.incomingQueue = new Queue(0);
     
        /* Set this Queue as the default Queue */
        this.tManager.setDefaultQueue(this.incomingQueue);
    }

    private void worker()
    {
        // TODO: Start tristanable manager here
        this.tManager.start();

        logger.info("Connection thread '"~this.toString()~"' started");

        // TODO: Well, we'd tasky I guess so I'd need to use it there I guess

        // TODO: Add worker function here
        while(true)
        {
            // TODO: Addn a tasky/tristanable queue managing thing with
            // ... socket here (probably just the latter)
            // ... which decodes using the `davinci` library

            // Dequeue a message from the incoming queue
            TaggedMessage incomingMessage = incomingQueue.dequeue();

            // Process the message
            handle(incomingMessage);
        }
    }

    private void handle(TaggedMessage incomingMessage)
    {
        logger.dbg("Examining message '"~incomingMessage.toString()~"' ...");
    }

    /** 
     * Creates a new connection by associating a newly created
     * Connection instance with the provided Server and Socket
     * after which it will be added to the server's connection
     * queue, finally starting the thread that manages this connection
     *
     * TODO: Change this, the returning is goofy ah, I think perhaps
     * we should only construct it and then let `Server.addConnection()`
     * call start etc. - seeing that a Listener will call this
     *
     * Params:
     *   associatedServer = the server to associate with
     *   clientStream = the associated stream backing the client
     *
     * Returns: the newly created Connection object
     */
    public static Connection newConnection(Server associatedServer, Stream clientStream)
    {
        Connection conn = new Connection(associatedServer, clientStream);

        /* Associate this connection with the provided server */
        associatedServer.addConnection(conn);

        /* Start the worker on a seperate thread */
        // new Thread(&worker);
        conn.start();


        return conn;
    }
}