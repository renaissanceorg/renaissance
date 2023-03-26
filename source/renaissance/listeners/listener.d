module renaissance.listeners.listener;

import renaissance.server;

public abstract class Listener
{
    /** 
     * Associated server to add new connections
     * to
     */
    private Server server;

    /** 
     * Constructs a new Listener and associates it with
     * the provided consumer
     *
     * Params:
     *   server = the server to consume new connections
     */
    this(Server server)
    {
        this.server = server;
    }
}