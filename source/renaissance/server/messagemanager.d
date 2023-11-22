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

/** 
 * The verdict of any `PolicyFunction`
 *
 * This drives the decisions made
 * within the `Queue` in terms of
 * how it shoukd behave
 */
public enum PolicyDecision
{
    /**
     * Don't modify the queue
     * at all. Essentially
     * dropping the incoming
     * item
     */
    DROP_INCOMING,

    /**
     * The item at the tail
     * of the queue should be
     * dropped so as to make
     * space for a new item
     * in its place
     */
    DROP_TAIL,
    
    /** 
     * The incoming item
     * should be appended
     * to the queue
     */
    ACCEPT
}

/** 
 * Describes a delegate which can be used
 * for examining the latest item incoming
 * the queue, along with the queue itself
 * and return a verdict based on it
 */
public alias PolicyFunction = PolicyDecision delegate(Message, QueueIntrospective);

/** 
 * NOP policy does nothing and always
 * returns a positive (`ACCEPT`'d)
 * verdict
 *
 * Returns: `PolicyDecision.ACCEPT` always
 */
public PolicyDecision nop(Message, QueueIntrospective)
{
    return PolicyDecision.ACCEPT;
}

public struct SmartPolicy
{
    private size_t maxSize;

    @disable
    private this();

    this(size_t maxSize)
    {
        this.maxSize = maxSize;
    }

    public PolicyDecision enact(Message message, QueueIntrospective queue)
    {
        // TODO: Implement me


        return PolicyDecision.ACCEPT;
    }

}

/** 
 * Defines the interface which policy
 * functions can use in order to access
 * the internals of a given queue
 */
public interface QueueIntrospective
{
    private void lockQueue();
    private DList!(Message) getQueue();
    private void unlockQueue();
}

public enum QUEUE_DEFAULT_SIZE = 100;

// TODO: Templatize in the future on the T element type
public class Queue : QueueIntrospective
{
    private PolicyFunction policy;
    private DList!(Message) queue;
    private Mutex lock;

    import std.functional : toDelegate;
    public this(PolicyFunction policy = toDelegate(&nop))
    {
        this.lock = new Mutex();
        this.policy = policy;
    }

    public static Queue makeSmart(size_t maxSize)
    {
        SmartPolicy smartPolicy = SmartPolicy(maxSize);
        PolicyFunction smartPolicyFunction = &smartPolicy.enact;

        Queue smartQueue = new Queue(smartPolicyFunction);
        return smartQueue;
    }

    public static makeSmart()
    {
        return makeSmart(QUEUE_DEFAULT_SIZE);
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

    private void lockQueue()
    {
        // Lock the queue
        this.lock.lock();
    }

    private void unlockQueue()
    {
        // Unlock the queue
        return this.lock.unlock();
    }

    private DList!(Message) getQueue()
    {
        return this.queue;
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
        // this.sendQueue = new Queue();
        // this.receiveQueue = new Queue();
        this.sendQueue = Queue.makeSmart();
        this.receiveQueue = Queue.makeSmart();
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