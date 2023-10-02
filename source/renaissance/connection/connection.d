module renaissance.connection.connection;

import davinci;
import core.thread : Thread;
import renaissance.server;
import river.core;
import tristanable;
import renaissance.logging;

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

        // TODO: Add ourselves to the server's queue, we might need to figure out, first what
        // ... kind of connection we are

        // TODO: Well, we'd tasky I guess so I'd need to use it there I guess

        // TODO: Add worker function here
        while(true)
        {
            // TODO: Addn a tasky/tristanable queue managing thing with
            // ... socket here (probably just the latter)
            // ... which decodes using the `davinci` library

            import core.thread;
            // Thread.sleep(dur!("seconds")(5));

            // FIXME: If connection dies, something spins inside tristanable me thinks
            // ... causing a high load average, it MIGHT be when an error
            // ... occurs that it keeps going back to ask for recv
            // ... (this would make sense as this woul dbe something)
            // ... we didn't test for

            // Dequeue a message from the incoming queue
            TaggedMessage incomingMessage = incomingQueue.dequeue();

            logger.dbg("Awoken? after dequeue()");

            // Process the message
            handle(incomingMessage);
        }
    }

    /** 
     * Given a `TaggedMessage` this method will decode
     * it into a Davinci `BaseMessage`, determine the
     * payload type via this header and then handle
     * the message/command accordingly
     *
     * Params:
     *   incomingMessage = the `TaggedMessage`
     */
    private void handle(TaggedMessage incomingMessage)
    {
        logger.dbg("Examining message '"~incomingMessage.toString()~"' ...");

        byte[] payload = incomingMessage.getPayload();
        import davinci;
        BaseMessage baseMessage = BaseMessage.decode(payload);
        logger.dbg("Incoming message: "~baseMessage.getCommand().toString());
        
        logger.dbg("BaseMessage type: ", baseMessage.getMessageType());

        if(baseMessage.getCommandType() == CommandType.NOP_COMMAND)
        {
            import davinci.c2s.test;
            logger.dbg("We got a NOP");
            TestMessage nopMessage = cast(TestMessage)baseMessage.getCommand();

            // TODO: This is for testing, I send the nop back
            this.tManager.sendMessage(incomingMessage);
        }
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