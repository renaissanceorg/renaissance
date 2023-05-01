/** 
 * Listener type definitions
 */
module renaissance.listeners.listener;

import renaissance.server;

/** 
 * Represents a producer of Connection objects
 * which can then be associated with the Server
 * attached to this listener
 */
public abstract class Listener
{
    /** 
     * Associated server to add new connections
     * to
     */
    protected Server server;

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

    // TODO: Maybe we an add attach method here - who knows

    public abstract void startListener();

    public abstract void stopListener();
}