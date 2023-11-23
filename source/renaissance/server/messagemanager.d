module renaissance.server.messagemanager;

import renaissance.server.server : Server;
import std.container.dlist : DList;
import core.sync.mutex : Mutex;
import renaissance.logging;

/** 
 * An in-memory representation of
 * a message
 */
public struct Message
{
    private string destination;
    private string message;
    private string from;

    /** 
     * Constructs a new message
     *
     * Params:
     *   destination = the destination
     *   from = the from user
     *   message = the message itself
     */
    this(string destination, string from, string message)
    {
        this.destination = destination;
        this.from = from;
        this.message = message;
    }

    /** 
     * Sets the message's body
     *
     * Params:
     *   message = the contents
     */
    public void setBody(string message)
    {
        this.message = message;
    }

    /** 
     * Sets the from paramneter
     *
     * Params:
     *   from = the username
     */
    public void setFrom(string from)
    {
        this.from = from;
    }

    /** 
     * Sets the destination of this message
     *
     * Params:
     *   destination = the username
     */
    public void setDestination(string destination)
    {
        this.destination = destination;
    }

    /** 
     * Returns the contents of this
     * message
     *
     * Returns: the contents
     */
    public string getBody()
    {
        return this.message;
    }

    /** 
     * Returns the from parameter
     *
     * Returns: the username
     */
    public string getFrom()
    {
        return this.from;
    }

    /** 
     * Returns the destination
     *
     * Returns: the username
     */
    public string getDestination()
    {
        return this.destination;
    }
}

public enum QUEUE_DEFAULT_SIZE = 100;

public enum PolicyDecision
{
    DROP_INCOMING,
    DROP_TAIL,
    ACCEPT
}

// TODO: Templatize in the future on the T element type
public class Queue
{
    private size_t maxSize;
    private DList!(Message) queue;
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

        // Apply queuing policy
        PolicyDecision decision = policyCheck();
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

    private PolicyDecision policyCheck() // NOTE: In future must use lock if decision requires anlysing internal queue
    {
        // TODO: Implement me
        return PolicyDecision.ACCEPT;
    }
}

/** 
 * Defines an interface of methods
 * which are to be called whenever
 * new messages are enqueued onto
 * a so-called "incoming" (recv-q)
 * and "outgoing" (send-q) queues
 *
 * The `MessageManager` will use
 * these as the hooks it applies
 * to its send/recv queues.
 *
 * An example usage of this is
 * to allow `Server` to get notified
 * whenever a new item appears.
 */
public interface MessageDeliveryTransport
{
    /** 
     * Called when a message has just been
     * enqueued to the incoming queue
     *
     * Params:
     *   latest = the latest message
     *   from = the queue
     * Returns: `true` if you handled
     * this without error, `false`
     * otherwise
     */
    public bool onIncoming(Message latest, Queue from);

    /** 
     * Called when a message has just been
     * enqueued to the outgoing queue
     *
     * Params:
     *   latest = the latest message
     *   from = the queue
     * Returns: `true` if you handled
     * this without error, `false`
     * otherwise
     */
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