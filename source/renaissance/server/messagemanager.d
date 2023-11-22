module renaissance.server.messagemanager;

import renaissance.server.server : Server;
import std.container.slist : SList;
import core.sync.mutex : Mutex;
import renaissance.logging;

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

    public void setBody(string message)
    {
        this.message = message;
    }

    public void setFrom(string from)
    {
        this.from = from;
    }

    public void setDestination(string destination)
    {
        this.destination = destination;
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
    private MessageDeliveryTransport transport;

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
        logger.info("Received message for sending: ", message);

        // Enqueue to send-q
        this.sendQueue.enqueue(message);
    }

    public void recvq(Message message)
    {
        logger.info("Received message for reception: ", message);

        // Enqueue to recv-q
        this.receiveQueue.enqueue(message);
    }
    
    public static MessageManager create(MessageDeliveryTransport transport)
    {
        MessageManager manager = new MessageManager();
        manager.transport = transport;


        return manager;
    }
}