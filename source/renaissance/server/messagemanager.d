module renaissance.server.messagemanager;

import renaissance.server.server : Server;
import std.container.slist : SList;
import core.sync.mutex : Mutex;

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
    private Mutex lock;

    public this(size_t maxSize = QUEUE_DEFAULT_SIZE)
    {
        this.lock = new Mutex();
    }

    public void enqueue(Message message)
    {
        // Lock the queue
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the queue
            this.lock.unlock();
        }

        // Enqueue
        this.queue.insertAfter(this.queue[], message);
    }
}


public interface MessageDeliveryTransport
{
    // On incoming message
    public bool onIncoming(Message latest, Queue from);

    // On message that must be egressed
    public bool onOutgoing(Message latest, Queue from);
}

// TODO: Should have a thread that manages
// ... message delivery by just calling something
// ... in server (it must handle encoding and 
// ... so forth)
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

    public void sendq(Message message)
    {

    }

    public void recvq(Message message)
    {

    }
    
    public static MessageManager create(Server server)
    {
        MessageManager manager = new MessageManager();
        manager.server = server;


        return manager;
    }
}