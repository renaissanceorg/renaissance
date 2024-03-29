module renaissance.connection.connection;

import davinci;
import core.thread : Thread;
import renaissance.server;
import river.core;
import tristanable;
import renaissance.logging;
import renaissance.server.messagemanager : MessageManager, Message;


import davinci.base.components : Validatable;

import davinci.c2s.auth : AuthMessage, AuthResponse;
import davinci.c2s.generic : UnknownCommandReply;

import davinci.c2s.channels : ChannelEnumerateRequest, ChannelEnumerateReply, ChannelMembership, ChannelMessage;
import davinci.c2s.test : NopMessage;
import renaissance.server.channelmanager : ChannelManager, Channel;

import std.conv : to;

public enum LinkType
{
    UNSET,
    USER,
    SERVER
}

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

    /** 
     * Whether this is a user connection
     * or a server link
     */
    private LinkType linkType;

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

    public LinkType getLinkType()
    {
        return this.linkType;
    }

    private void worker()
    {
        // TODO: Start tristanable manager here
        this.tManager.start();

        logger.info("Connection thread '"~this.toString()~"' started");

        // TODO: Add ourselves to the server's queue, we might need to figure out, first what
        // ... kind of connection we are

        // TODO: Well, we'd tasky I guess so I'd need to use it there I guess

        // TODO: Imp,ent nthe loop condition status (exit on error)
        bool isGood = true;
        while(isGood)
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

        // Clean up (TODO: Shutdown the TManager)
        

        // Clean up - notify disconnection
        this.associatedServer.onConnectionDisconnect(this);
    }

    // FIXME: These should be part of the auth details
    // ... associated with this user
    string myUsername = "bababooey";

    private bool isAuthd()
    {
        return myUsername.length != 0;
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
        // TODO: In future this decoder, surely, should be idk
        // ... in davinci as in stateful encoder/decoder
        // ... reply-generator
        logger.dbg("Examining message '"~incomingMessage.toString()~"' ...");

        byte[] payload = incomingMessage.getPayload();
        import davinci;
        BaseMessage baseMessage = BaseMessage.decode(payload);
        logger.dbg("Incoming message: "~baseMessage.getCommand().toString());
        
        logger.dbg("BaseMessage type: ", baseMessage.getMessageType());
        Command incomingCommand = baseMessage.getCommand();
        CommandType incomingCommandType = baseMessage.getCommandType();
        logger.dbg("Incoming CommandType: ", incomingCommandType);

        BaseMessage response;
        MessageType mType;
        Command responseCommand;
        CommandType responseType;
        Status responseStatus;

        /** 
         * Perform validation before continueing
         */
        if(cast(Validatable)incomingCommand)
        {
            Validatable validtabaleCommand = cast(Validatable)incomingCommand;
            string reason;
            if(!validtabaleCommand.validate(reason))
            {
                logger.error("Validation failed with reason: '", reason, "'");

                
                UnknownCommandReply unknownCmdReply = new UnknownCommandReply(reason);

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.UNKNOWN_COMMAND;
                responseCommand = unknownCmdReply;

                // TODO: Can we do this without gotos?
                goto encode_n_send;
            }
        }

        /** 
         * Handle the different types of commands
         */
        switch(incomingCommandType)
        {
            /** 
             * Handle NOP commands
             */
            case CommandType.NOP_COMMAND:
            {
                logger.dbg("We got a NOP");
                NopMessage nopMessage = cast(NopMessage)baseMessage.getCommand();

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.NOP_COMMAND;
                responseCommand = nopMessage;

                break;
            }
            /**
             * Handle authentication request
             */
            case CommandType.AUTH_COMMAND:
            {
                AuthMessage authMessage = cast(AuthMessage)baseMessage.getCommand();
                bool status = this.associatedServer.attemptAuth(authMessage.getUsername(), authMessage.getPassword());

                // TODO: This is just for testing now - i intend to have a nice auth manager
                
                
                AuthResponse authResp = new AuthResponse();
                if(status)
                {
                    authResp.good();

                    // Save username
                    this.myUsername = authMessage.getUsername();
                }
                else
                {
                    authResp.bad();
                }

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.AUTH_RESPONSE;
                responseCommand = authResp;

                break;
            }
            /**
             * Handle channel list requests
             */
            case CommandType.CHANNELS_ENUMERATE_REQ:
            {
                // FIXME: Figure out how we want to do auth checks
                if(!isAuthd())
                {

                }
                
                ChannelEnumerateRequest chanEnumReq = cast(ChannelEnumerateRequest)baseMessage.getCommand();
                ubyte limit = chanEnumReq.getLimit();
                ulong offset = chanEnumReq.getOffset();

                string[] channelNames = this.associatedServer.getChannelNames(offset, limit);
                ChannelEnumerateReply chanEnumRep = new ChannelEnumerateReply(channelNames);

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.CHANNELS_ENUMERATE_REP;
                responseCommand = chanEnumRep;

                break;
            }
            /**
             * Handle channel joins
             */
            case CommandType.MEMBERSHIP_JOIN:
            {
                ChannelMembership chanMemReq = cast(ChannelMembership)baseMessage.getCommand();
                string channel = chanMemReq.getChannel();

                // Join the channel
                ChannelManager chanMan = this.associatedServer.getChannelManager();
                bool status = chanMan.membershipJoin(channel, this.myUsername); // TODO: Handle return value
                chanMemReq.replyGood();

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.MEMBERSHIP_JOIN_REP;
                responseCommand = chanMemReq;

                break;
            }
            /**
             * Handle channel membership requests
             */
            case CommandType.MEMBERSHIP_LIST:
            {
                ChannelMembership chanMemReq = cast(ChannelMembership)baseMessage.getCommand();
                string channel = chanMemReq.getChannel();

                // Obtain the current members
                ChannelManager chanMan = this.associatedServer.getChannelManager();
                string[] currentMembers;
                
                // TODO: Handle return value
                bool status = chanMan.membershipList(channel, currentMembers);
                logger.dbg("Current members of '"~channel~"': ", currentMembers);
                chanMemReq.listReplyGood(currentMembers);

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.MEMBERSHIP_LIST_REP;
                responseCommand = chanMemReq;
                
                break;
            }
            /**
             * Handle channel leaves
             */
            case CommandType.MEMBERSHIP_LEAVE:
            {
                ChannelMembership chanMemReq = cast(ChannelMembership)baseMessage.getCommand();
                string channel = chanMemReq.getChannel();

                // Join the channel
                ChannelManager chanMan = this.associatedServer.getChannelManager();
                bool status = chanMan.membershipLeave(channel, this.myUsername); // TODO: Handle return value
                chanMemReq.replyGood();

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.MEMBERSHIP_LEAVE_REP;
                responseCommand = chanMemReq;

                break;
            }
            /**
             * Handle message sending
             */
            case CommandType.CHANNEL_SEND_MESSAGE:
            {
                ChannelMessage chanMesg = cast(ChannelMessage)baseMessage.getCommand();
            
                // TODO: Get channel, lookup and do permission checks

                // TODO: Use a messagemanager thing here
                MessageManager mesgMan = this.associatedServer.getMessageManager();


                // TODO: Check multiple recipients
                string[] recipients = chanMesg.getRecipients();
                foreach(string to; recipients)
                {
                    Message message;
                    message.setBody(chanMesg.getMessage());
                    message.setFrom(this.myUsername);
                    message.setDestination(to);

                    logger.dbg("Sending message: ", message);
                    mesgMan.sendq(message);
                }

                // TODO: Set this ONLY if we succeeeded in delivery
                chanMesg.messageDelivered();

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.SEND_CHANNEL_MESG_REP;
                responseCommand = chanMesg;

                break;
            }
            /** 
             * Anything else is an unknown
             * command, therefore generate
             * an error reply
             */
            default:
            {
                logger.warn("Received unsupported message type", baseMessage);
            
                UnknownCommandReply unknownCmdReply = new UnknownCommandReply("Command with type number: "~to!(string)(cast(ulong)incomingCommandType));

                mType = MessageType.CLIENT_TO_SERVER;
                responseType = CommandType.UNKNOWN_COMMAND;
                responseCommand = unknownCmdReply;

                logger.warn("We have generated err: ", responseCommand);
                break;
            }
        }

        encode_n_send:

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