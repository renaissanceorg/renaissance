module renaissance.server.server;

import std.container.slist : SList;
import core.sync.mutex : Mutex;
import renaissance.listeners;
import std.algorithm : canFind;
import renaissance.exceptions;
import renaissance.connection;
import renaissance.logging;
import renaissance.server.channelmanager;
import renaissance.server.users;
import renaissance.server.messagemanager;
import renaissance.connection.session;

/** 
 * Represents an instance of the daemon which manages
 * all listeners attached to it, server state and
 * message processing
 */
public class Server : MessageDeliveryTransport
{
    // TODO: array of listeners
    private SList!(Listener) listenerQ;
    private Mutex listenerQLock;

    // TODO: array of connections
    private SList!(Connection) connectionQ;
    private Mutex connectionQLock;

    // TODO: volatility
    private bool isRunning = false;

    private ChannelManager channelManager;

    // TODO: Some sendq/recq mechanism with messages or something
    // ... should be placed here

    private AuthManager authManager;

    private MessageManager messageManager;

    private SessionManager sessionManager;

    /** 
     * Constructs a new server
     */
    this()
    {
        /* Initialize all mutexes */
        this.listenerQLock = new Mutex();
        this.connectionQLock = new Mutex();

        /* Initialize the channel management sub-system */
        this.channelManager = ChannelManager.create(this);

        /* Initialize the authentication management sub-system */
        this.authManager = AuthManager.create(this); // TODO: Set custo provder here based on argument to this constructor

        /* Initialize the message management sub-system */
        this.messageManager = MessageManager.create(this);

        /* Initialize the session management sub-system */
        this.sessionManager = new SessionManager();
    }


    /** 
     * Starts the server by starting all listeners
     * and allowing connections to be added (TODO: implement the latter)
     */
    public void start()
    {
        // Set state to running
        isRunning = true;

        // TODO: How would we ensure that can can add listeners whilst running
        // ... perhaps listeners should? Maybe don't allow that
        // NOTE: Reason we have add listener here is such that if we shutdown we can
        // ... kill them all. I guess we need not dtart them but it won't hurt
        /* Start all listeners */
        startListeners();

        // TODO: If anything else must run then start a thread for it here
    }

    public void restart()
    {
        // TODO: This requires each listener to properly implement start and create its sockets or whatever
        // ... in the correct places

        stop();
        start();
    }

    /** 
     * Stops the server by stopping all listeners,
     * and disconnecting any connected clients (TODO: implement the latter)
     */
    public void stop()
    {
        // TODO: If the connection attempts to call `addConnection` and fails then it must kill itself
        /* Set state to not running (preventing any pending connections from being added) */
        isRunning = false;

        /* Stop all listeners to prevent any new connections coming in */
        stopListeners();

        // TODO: Remove all connection (disconnected currently added connections)
    }

    private void stopListeners()
    {
        /* Lock the listener queue */
        listenerQLock.lock();

        /* On return or exception */
        scope(exit)
        {
            /* Unlock the listener queue */
            listenerQLock.unlock();
        }

        /* Stop each listener */
        foreach(Listener curListener; listenerQ)
        {
            curListener.stopListener();
        }
    }

    private void startListeners()
    {
        /* Lock the listener queue */
        listenerQLock.lock();

        /* On return or exception */
        scope(exit)
        {
            /* Unlock the listener queue */
            listenerQLock.unlock();
        }

        /* Start each listener */
        foreach(Listener curListener; listenerQ)
        {
            logger.dbg("Starting listener '"~curListener.toString()~"' ...");
            curListener.startListener();
        }
    }

    /** 
     * Adds the provided listener to the server
     *
     * Params:
     *   newListener = the listener to be added
     * Throws:
     *   RenaissanceException = if the listener has already been added
     */
    public final void addListener(Listener newListener)
    {
        /* Lock the listener queue */
        listenerQLock.lock();

        /* On return or exception */
        scope(exit)
        {
            /* Unlock the listener queue */
            listenerQLock.unlock();
        }

        /* If the listener has NOT added */
        if(!canFind(listenerQ[], newListener))
        {
            /* Add the listener */
            listenerQ.insertAfter(listenerQ[], newListener);
        }
        /* If the listener has ALREADY been added */
        else
        {
            /* Throw an exception */
            throw new RenaissanceException(ErrorType.LISTENER_ALREADY_ADDED);
        }
    }

    // TODO: Add a `removeListener(Listener)` method


    // TODO: Unless the server is started, then don't allow connection additions
    /** 
     * Consumes the provided connection and adds it to the connection
     * queue
     *
     * Params:
     *   newConnection = the connection to add
     */
    public void addConnection(Connection newConnection)
    {
        /* Lock the connection queue */
        connectionQLock.lock();

        /* Add the connection */
        connectionQ.insertAfter(connectionQ[], newConnection);

        /* Unlock the connection queue */
        connectionQLock.unlock();
    }

    public string[] getChannelNames(ulong offset, ubyte limit)
    {
        // TODO: Implement me
        return this.channelManager.getChannelNames(offset, limit);
    }

    public ChannelManager getChannelManager()
    {
        return this.channelManager;
    }

    public MessageManager getMessageManager()
    {
        return this.messageManager;
    }

    public AuthManager getAuthenticationManager()
    {
        return this.authManager;
    }

    public SessionManager getSessionManager()
    {
        return this.sessionManager;
    }

    // On incoming message
    public bool onIncoming(Message latest, Queue from)
    {
        // TODO: Implement me
        logger.info("Incoming stub with latest ", latest, "from queue ", from);
        
        return true;
    }

    // On message that must be egressed
    public bool onOutgoing(Message latest, Queue from)
    {
        // TODO: Implement me
        logger.info("Outgoing stub with latest ", latest, "from queue ", from);

        // Lookup the user (source)
        User* fromUser = this.authManager.getUser(latest.getFrom());

        


        if(fromUser == null)
        {
            // TODO: Handle this
            logger.error("Could not find fromUser (User* was null)");
            return false;
        }
        else
        {
            logger.dbg("Found fromUser (User*)", fromUser.toString());
        }


        
        /**
         * Extract the intended destination
         *
         * Based on this we need to make a decision
         * as to whether the destination refers to:
         *
         * 1. A user
         * 2. A channel
         *
         * And we do it in that order
         */
        string destinationString = latest.getDestination();

        // Lookup the user (destination)
        User* toUser = this.authManager.getUser(destinationString);
        logger.dbg("Delivery type: ", toUser == null ? "toChannel": "toUser");

        // Selected destinations to deliver to
        User*[] selectedDestinations;

        // Delivery to user
        if(toUser != null)
        {
            // A single destination must be selected
            selectedDestinations = [toUser];
        }
        // Delivery to channel
        else
        {
            // If a channel exists with such a name
            if(this.channelManager.channelExists(destinationString))
            {
                string[] chanMembers;

                // Member lookup succeeds
                if(this.channelManager.membershipList(destinationString, chanMembers))
                {
                    foreach(string memUsername; chanMembers)
                    {
                        User* memberUser = this.authManager.getUser(memUsername);
                        if(memberUser != null)
                        {
                            // Select each member as a destination
                            selectedDestinations ~= memberUser;
                        }
                    }
                }
                // Member lookup fails
                else
                {
                    logger.error("Member lookup failed for destination channel '", destinationString, "'");
                    return false;
                }
            }
            // If the channel does not exist
            else
            {
                logger.error("Could not find a user or channel with the name '", destinationString, "'");
                return false;
            }
        }


        

        // TODO: Check if the name is that of a user, if so skip channel name check
        // TODO: We actually need to lookup members of the channel (destinations)
        // TODO: For each member do the below:


        // Deliver the message to each detination
        foreach(User* curDest; selectedDestinations)
        {
            logger.dbg("Delivering to user '", curDest, "'...");

            // Obtain the session of the destination user
            Session* toSession = this.sessionManager.getSession(curDest);

            // TODO: Handle case where user is offline (no Connection[]s)
            // ... the message manager must do this if false is returned
            foreach(Connection toLink; toSession.getLinks())
            {
                logger.dbg("Delivering message '", latest, "' to link ", toLink, " of user '", curDest, "'");
                if(!toLink.incomingMessage(latest))
                {
                    // TODO: Handle failed message?
                }
            }
        }


        

        return true;
    }
}

version(unittest)
{
    import renaissance.server;
    import renaissance.listeners;
    
    // TODO: Building a testing client with the imports below
    import std.socket;
    import tristanable.manager;
    // import tristanable.queue;
    import tristanable.encoding;
    import core.thread;

    import dante;
}

// unittest
// {
//     /** 
//      * Setup a `Server` instance followed by
//      * creating a single listener, after this
//      * start the server
//      */
//     Server server = new Server();
//     // Address listenAddr = parseAddress("::1", 9091);
//     Address listenAddr = new UnixAddress("/tmp/renaissance2.sock");
//     StreamListener streamListener = StreamListener.create(server, listenAddr);
//     server.start();

//     scope(exit)
//     {
//         import std.stdio;
//         remove((cast(UnixAddress)listenAddr).path().ptr);
//     }

//     // /**
//     //  * Create a few clients here (TODO: We'd need the client code)
//     //  */
//     // for(ulong idx = 0; idx < 10; idx++)
//     // {
//     //     Socket clientSocket = new Socket(listenAddr.addressFamily(), SocketType.STREAM);
//     //     clientSocket.connect(listenAddr);
//     //     Manager manager = new Manager(clientSocket);
//     //     Queue myQueue = new Queue(69);
//     //     manager.registerQueue(myQueue);
//     //     manager.start();

//     //     // Thread.sleep(dur!("seconds")(2));
//     //     TaggedMessage myMessage = new TaggedMessage(69, cast(byte[])"ABBA");
//     //     manager.sendMessage(myMessage);
//     //     manager.sendMessage(myMessage);
//     //     // Thread.sleep(dur!("seconds")(2));
//     //     manager.sendMessage(myMessage);
//     //     manager.sendMessage(myMessage);
//     // }

    
//     DanteClient client = new DanteClient(new UnixAddress("/tmp/renaissance2.sock"));

//     client.start();

//     client.nopRequest();
//     client.nopRequest();


//     // while(true)
//     // {
//     //     Thread.sleep(dur!("seconds")(20));
//     // }
// }