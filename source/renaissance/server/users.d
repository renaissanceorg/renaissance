module renaissance.server.users;

import core.sync.mutex : Mutex;

public enum Status
{
    ONLINE,
    OFFLINE,
    INVISIBLE,
    AWAY
}

public struct User
{
    private string username;
    private Status status;
    private Mutex lock;

    @disable
    private this();

    this(string username)
    {
        this.lock = new Mutex();
        setUsername(username);
    }

    // TODO: Disallow parameter less construction?

    public bool setUsername(string username)
    {
        // Username cannot be empty (TODO: Have a regex check)
        if(username.length == 0)
        {
            return false;
        }

        // Lock
        this.lock.lock();

        // Set the username
        this.username = username;

        // Unlock
        this.lock.unlock();

        return true;
    }
    
    public Status getStatus()
    {
        Status status;

        // Lock
        this.lock.lock();

        // Get the status
        status = this.status;

        // Unlock
        this.lock.unlock();

        return status;
    }
}


unittest
{
    User u = User("deavmi");
    
}