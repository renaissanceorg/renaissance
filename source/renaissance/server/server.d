module renaissance.server.server;

import std.container.slist : SList;
import core.sync.mutex : Mutex;
import renaissance.listeners;
import std.algorithm : canFind;
import renaissance.exceptions;
import renaissance.connection;

/** 
 * Represents an instance of the daemon which manages
 * all listeners attached to it, server state and
 * message processing
 */
public class Server
{
    // TODO: array of listeners
    private SList!(Listener) listenerQ;
    private Mutex listenerQLock;

    // TODO: array of connections
    private SList!(Connection) connectionQ;
    private Mutex connectionQLock;

    // TODO: volatility
    private bool isRunning = false;

    // TODO: Add constructor
    this()
    {
        /* Initialize all mutexes */
        this.listenerQLock = new Mutex();
        this.connectionQLock = new Mutex();
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
}