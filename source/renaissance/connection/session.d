module renaissance.connection.session;

import renaissance.connection.connection : Connection;
import renaissance.server.users : User;
import core.sync.mutex : Mutex;

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

    @disable
    private this();

    this(User* user)
    {
        this.user = user;
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
            return *foundPot;
        }
        else
        {
            Session* allocatedSession = new Session(allocatedRecord);
            this.sessions[allocatedRecord.getUsername()] = allocatedSession;
            return allocatedSession;
        }
    }
}