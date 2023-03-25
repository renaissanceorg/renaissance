module renaissance.listeners.listener;

import renaissance.listeners.consumer : ConnectionConsumer;

public abstract class Listener
{
    /** 
     * Any connections that we produce will be
     * consumed by this consumer (pushed into it)
     */
    private ConnectionConsumer consumer;

    /** 
     * Constructs a new Listener and associates it with
     * the provided consumer
     *
     * Params:
     *   consumer = the ConnectionConsumer to consume new connections
     */
    this(ConnectionConsumer consumer)
    {
        this.consumer = consumer;
    }
}