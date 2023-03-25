module renaissance.listeners.listener;

import renaissance.server;

public abstract class Listener
{
    private Server server;

    /** 
     * Constructs a new Listener and associates it with
     * the provided server instance
     * Params:
     *   server = the Server instance to attach the listener to
     */
    this(Server server)
    {
        this.server = server;
    }
}