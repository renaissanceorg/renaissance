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
            TaggedMessage response = handle(incomingMessage);
            if(response !is null)
            {
                logger.dbg("There was a response, sending: ", response);
                this.tManager.sendMessage(incomingMessage);
            }
            else
            {
                logger.dbg("There was no response, not sending anything.");
            }
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
     * Returns: the response `TaggedMessage`, or
     * `null` if no response is to be sent
     */
    private TaggedMessage handle(TaggedMessage incomingMessage)
    {
        logger.dbg("Examining message '"~incomingMessage.toString()~"' ...");

        byte[] payload = incomingMessage.getPayload();
        import davinci;
        BaseMessage baseMessage = BaseMessage.decode(payload);
        logger.dbg("Incoming message: "~baseMessage.getCommand().toString());
        
        logger.dbg("BaseMessage type: ", baseMessage.getMessageType());

        BaseMessage response;
        MessageType mType;
        Command responseCommand;
        CommandType responseType;

        if(baseMessage.getCommandType() == CommandType.NOP_COMMAND)
        {
            import davinci.c2s.test;
            logger.dbg("We got a NOP");
            NopMessage nopMessage = cast(NopMessage)baseMessage.getCommand();

            mType = MessageType.CLIENT_TO_SERVER;
            responseType = CommandType.NOP_COMMAND;
            responseCommand = nopMessage;
        }
        // Handle authentication request
        else if(baseMessage.getCommandType() == CommandType.AUTH_COMMAND)
        {
            import davinci.c2s.auth : AuthMessage, AuthResponse;

            AuthMessage authMessage = cast(AuthMessage)baseMessage.getCommand();
            bool status = this.associatedServer.attemptAuth(authMessage.getUsername(), authMessage.getPassword());
            
            AuthResponse authResp = new AuthResponse();
            if(status)
            {
                authResp.good();
            }
            else
            {
                authResp.bad();
            }

            mType = MessageType.CLIENT_TO_SERVER;
            responseType = CommandType.AUTH_RESPONSE;
            responseCommand = authResp;
        }
        // Handle channel list requests
        else if(baseMessage.getCommandType() == CommandType.CHANNELS_ENUMERATE_REQ)
        {
            import davinci.c2s.channels : ChannelEnumerateRequest, ChannelEnumerateReply;

            ChannelEnumerateRequest chanEnumReq = cast(ChannelEnumerateRequest)baseMessage.getCommand();
            ubyte limit = chanEnumReq.getLimit();
            ulong offset = chanEnumReq.getOffset();

            string[] channelNames = this.associatedServer.getChannelNames(offset, limit);
            ChannelEnumerateReply chanEnumRep = new ChannelEnumerateReply(channelNames);

            mType = MessageType.CLIENT_TO_SERVER;
            responseType = CommandType.CHANNELS_ENUMERATE_REP;
            responseCommand = chanEnumRep;
        }
        // Unsupported type for server
        else
        {
            logger.warn("Received unsupported message type", baseMessage);

            // TODO: Generate error here
        }

        // Generate response
        response = new BaseMessage(mType, responseType, responseCommand);

        // Construct a response using the same tag
        // (for matching) but a new payload (the
        // response message)
        incomingMessage.setPayload(response.encode());
        
        return incomingMessage;
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