module renaissance.connection.session;

import renaissance.connection.connection : Connection;
import renaissance.server.users : User;
import core.sync.mutex : Mutex;
import renaissance.logging;
import std.conv : to;

// TODO: One of these should be opened as soon as auth is
// ... done and stored in server so as to be able to map to it
// It must be pooled by the username and then appended to

// Whilst a User* is for the profile effectively, then
// a Session is an active set of network links such a User*
// has active
public struct Session
{
    private Connection[] links;
    private User* user;
    private Mutex lock;

    @disable
    private this();

    this(User* user)
    {
        this.user = user;
        this.lock = new Mutex();
    }

    public void linkConnection(Connection conn)
    {
        // Lock the session
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the session
            this.lock.unlock();
        }

        // TODO: Safety of not inserting the same entry? (Not major thing for me imo as it comes down just to correct usage)
        this.links ~= conn;
        logger.dbg("Linked connection", conn);
    }

    public void unlinkConnection(Connection conn)
    {
        // Lock the session
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the session
            this.lock.unlock();
        }

        // Remove from list
        Connection[] newLinks;
        foreach(Connection cur; this.links)
        {
            if(cur !is conn)
            {
                newLinks ~= cur;
            }
        }

        // Use new list
        this.links = newLinks;

        logger.dbg("Delinked connection", conn);
    }

    public Connection[] getLinks()
    {
        // Lock the session
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the session
            this.lock.unlock();
        }

        return this.links.dup;
    }

    public string toString()
    {
        // Lock the session
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the session
            this.lock.unlock();
        }

        return "Session [user: "~to!(string)(this.user)~", links: "~to!(string)(this.links.length)~"]";
    }
}

public class SessionManager
{
    // username -> Session*
    private Session*[string] sessions;
    private Mutex sessionsLock;

    this()
    {
        /* Initialize the sessions map lock */
        this.sessionsLock = new Mutex();
    }

    public void addConnection(User* allocatedRecord, Connection fromConnection)
    {
        // TODO: Map the `allocatedRecord` to a session (pool, so if one doesn't
        // ... exist then create it), afterwhich tack on the `fromConnection`

        Session* session = poolSession(allocatedRecord);
        logger.dbg("Pooled session: ", session);

        // Add the connection
        session.linkConnection(fromConnection);
    }

    public Session* getSession(User* allocatedRecord)
    {
        return poolSession(allocatedRecord);
    }

    private Session* poolSession(User* allocatedRecord)
    {
        // Lock the sessions map
        this.sessionsLock.lock();

        // On exit
        scope(exit)
        {
            // Unlock the sessions map
            this.sessionsLock.unlock();
        }

        Session** foundPot = allocatedRecord.getUsername() in this.sessions;
        if(foundPot != null)
        {
            logger.dbg("Pooled an existing session (", *foundPot, ") for user '", allocatedRecord, "'");
            return *foundPot;
        }
        else
        {
            logger.warn("Session did not exist for '", allocatedRecord, "' therefore creating one");
            Session* allocatedSession = new Session(allocatedRecord);
            this.sessions[allocatedRecord.getUsername()] = allocatedSession;
            return allocatedSession;
        }
    }
}