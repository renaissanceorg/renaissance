module renaissance.listeners.consumer;

import renaissance.connection;

/** 
 * Any class which implements this interface can
 * have new Connection(s) passed to it (i.e. "consumed")
 */
public interface ConnectionConsumer
{
    public void addConnection(Connection connection);
}