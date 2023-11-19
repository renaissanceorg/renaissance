module renaissance.server.messagemanager;

import renaissance.server.server : Server;
import std.container.slist : SList;

public struct Message
{
    private string destination;
    private string message;
    private string from;

    this(string destination, string from, string message)
    {
        this.destination = destination;
        this.from = from;
        this.message = message;
    }
}

public enum QUEUE_DEFAULT_SIZE = 100;

public class Queue
{
    private size_t maxSize;
    private SList!(Message) queue;

    public this(size_t maxSize = QUEUE_DEFAULT_SIZE)
    {

    }
}

public class MessageManager
{
    private Server server;

    private Queue sendQueue;
    private Queue receiveQueue;

    private this()
    {
        // Initialize the queues (send+receive)
        this.sendQueue = new Queue();
        this.receiveQueue = new Queue();
    }
    
    public static MessageManager create(Server server)
    {
        MessageManager manager = new MessageManager();
        manager.server = server;


        return manager;
    }
}