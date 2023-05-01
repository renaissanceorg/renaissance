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

    // TODO: Add constructor
    this()
    {
        /* Initialize all mutexes */
        this.listenerQLock = new Mutex();
        this.connectionQLock = new Mutex();
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
        /* If the listener has ALEADY been added */
        else
        {
            /* Throw an exception */
            throw new RenaissanceException(ErrorType.LISTENER_ALREADY_ADDED);
        }
    }

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