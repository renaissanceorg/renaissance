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

    public enum Mode : ubyte
    {
        TAIL_DROP_ON_FULL = 0,
        DROP_INCOMING_ON_FULL = 1
    }

    @disable
    private this();

    this(size_t maxSize)
    {
        this.maxSize = maxSize;
        logger.dbg("maxSize (init): ", this.maxSize);
    }

    private Mode mode;

    private bool shouldTailDrop()
    {
        Mode dropMode = cast(Mode)( (cast(ubyte)this.mode) & 1 );

        return dropMode == Mode.TAIL_DROP_ON_FULL;
    }

    public PolicyDecision enact(Message message, QueueIntrospective queue)
    {
        // Lock the queue
        queue.lockQueue();

        // On exit
        scope(exit)
        {
            // Unlock the queue
            queue.unlockQueue();
        }

        // If we have space
        import std.range : walkLength;
        size_t curLen = walkLength(queue.getQueue()[]);
        logger.dbg("curLen:", curLen);
        logger.dbg("curLen+1:", curLen+1);
        logger.dbg("maxSize:", maxSize);

        // Is there space?
        if(curLen+1 <= maxSize)
        {
            return PolicyDecision.ACCEPT;
        }
        // There is no space
        else
        {
            // Drop tail on full
            if(shouldTailDrop)
            {
                return PolicyDecision.DROP_TAIL;
            }
            // Drop incoming on full
            else
            {
                return PolicyDecision.DROP_INCOMING;
            }
        }
    }

}

/** 
 * Defines the interface which policy
 * functions can use in order to access
 * the internals of a given queue
 */
public interface QueueIntrospective
{
    protected void lockQueue();
    protected ref DList!(Message) getQueue();  // NOTE: TO not copy the struct, also could allow replacing whole item (NOT GOOD)
    protected void unlockQueue();
}

public enum QUEUE_DEFAULT_SIZE = 0;

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

    protected void lockQueue()
    {
        // Lock the queue
        this.lock.lock();
    }

    protected void unlockQueue()
    {
        // Unlock the queue
        return this.lock.unlock();
    }

    protected ref DList!(Message) getQueue()
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

    // This is just for testing
    private SmartPolicy smrtPol;

    private this()
    {
        // Initialize the queues (send+receive)
        // this.sendQueue = new Queue();
        // this.receiveQueue = new Queue();

        this.smrtPol = SmartPolicy(QUEUE_DEFAULT_SIZE);
        this.sendQueue = new Queue(&smrtPol.enact);
        this.receiveQueue = new Queue(&smrtPol.enact);
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