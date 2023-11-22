module renaissance.server.messagemanager;

import renaissance.server.server : Server;
import std.container.dlist : DList;
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

public enum PolicyDecision
{
    DROP_INCOMING,
    DROP_TAIL,
    ACCEPT
}

/** 
 * Describes a function which can be used
 * for examining the latest item incoming
 * the queue, along with the queue itself
 * and return a verdict based on it
 */
public alias PolicyFunction = PolicyDecision function(Message, Queue);

/** 
 * NOP policy does nothing and always
 * returns a positive (`ACCEPT`'d)
 * verdict
 *
 * Returns: `PolicyDecision.ACCEPT` always
 */
public PolicyDecision nop(Message, Queue)
{
    return PolicyDecision.ACCEPT;
}

// TODO: Templatize in the future on the T element type
public class Queue
{
    private size_t maxSize;
    private PolicyFunction policy;
    private DList!(Message) queue;
    private Mutex lock;

    public this(size_t maxSize = QUEUE_DEFAULT_SIZE, PolicyFunction policy = &nop)
    {
        this.lock = new Mutex();
        this.policy = policy;
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

        // Apply queuing policy
        PolicyDecision decision = policy(message, this);
        logger.dbg("Queue decision: ", decision);

        // If we should tail-drop
        if(decision == PolicyDecision.DROP_TAIL)
        {
            // Drop tail
            this.queue.removeBack();
        }
        // If we should drop the incoming
        else if(decision == PolicyDecision.DROP_INCOMING)
        {
            // Do not insert
            return;
        }
        // Accept
        else if(decision == PolicyDecision.ACCEPT)
        {
            // Fall through
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

        // Deliver
        stubDeliverSend(message, this.sendQueue);
    }

    public void recvq(Message message)
    {
        logger.info("Received message for reception: ", message);

        // Enqueue to recv-q
        this.receiveQueue.enqueue(message);

        // Deliver
        stubDeliverRecv(message, this.receiveQueue);
    }

    // NOTE: Stub delivery method - not smart in anyway
    private void stubDeliverSend(Message latest, Queue from)
    {
        transport.onOutgoing(latest, from);
    }

    // NOTE: Stub delivery method - not smart in anyway
    private void stubDeliverRecv(Message latest, Queue from)
    {
        transport.onIncoming(latest, from);
    }
    
    public static MessageManager create(MessageDeliveryTransport transport)
    {
        MessageManager manager = new MessageManager();
        manager.transport = transport;


        return manager;
    }
}