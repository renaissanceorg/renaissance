module renaissance.server.users;

import core.sync.mutex : Mutex;

public struct Option
{
    // TODO: Implement me
    private string name;
    private ubyte[] value;
    private string description;
    private Mutex lock;

    @disable
    private this();

    public this(string name)
    {
        this.lock = new Mutex();
        this.name = name;
    }

    public string getName()
    {
        // Lock
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock
            this.lock.unlock();
        }

        // NOTE: String is immutable but incase of cast
        return name.dup;
    }

    public void setName(string name)
    {
        // Lock
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock
            this.lock.unlock();
        }

        // Copy the argument
        this.name = name.dup;
    }

    public ubyte[] getValue()
    {
        // Lock
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock
            this.lock.unlock();
        }

        return this.value.dup;
    }

    public void setValue(ubyte[] value)
    {
        // Lock
        this.lock.lock();

        // On exit
        scope(exit)
        {
            // Unlock
            this.lock.unlock();
        }

        // Copy the argument
        this.value = value.dup;
    }
}

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
    private Option*[string] options; // Profile key-value
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

    public string getUsername()
    {
        string usernameCpy;

        // Lock
        this.lock.lock();

        // Get the username
        usernameCpy = this.username;

        // Unlock
        this.lock.unlock();

        return usernameCpy;
    }
    
    public Status getStatus()
    {
        Status statusCpy;

        // Lock
        this.lock.lock();

        // Get the status
        statusCpy = this.status;

        // Unlock
        this.lock.unlock();

        return statusCpy;
    }

    public void addOption(Option* option)
    {
        // Lock
        this.lock.lock();

        // Insert the option
        this.options[option.getName()] = option;

        // Unlock
        this.lock.unlock();
    }
}


unittest
{
    User u = User("deavmi");
    assert(u.getUsername(), "deavmi");

    // Change the username
    u.setUsername("gustav");
    assert(u.getUsername(), "gustav");
    
}

public interface AuthProvider
{
    public bool authenticate(string username, string password);
}

public class DummyProvider : AuthProvider
{
    public bool authenticate(string username, string password)
    {
        return true;
    }
}

import renaissance.server.server : Server;
import renaissance.logging;

// Should handle all users authenticated and
// act as an information base for the current
// users
public class AuthManager
{
    private Server server;

    // TODO: Need an AuthProvider here
    private AuthProvider provider;

    /** 
     * TODO: We need to find a way to easily 
     * manage User* mapped to by a string (username)
     * and how updating the username (key) would
     * work (including the allocated value)
     * then
     *
     * Update: We won't expose this User*
     * to the public API as that means
     * you can manipulate the user
     * there (that is fine) but ALSO
     * replace the entire user there
     *
     * Nah, forget the above we should discern
     * between username (never changing)
     * and nick
     *
     * UPDATE2: We will STILL need to index (somehow)
     * on that then, perhaps a seperate 
     *
     * What is the point of usernames? for
     * auth but then nick is what people _should_
     * see when you `membershipList()`.
     * 
     * So we would need to update
     * ChannelManager code to do that
     * 
     */
    private User*[string] users;
    private Mutex usersLock;

    private this(AuthProvider provider)
    {
        this.usersLock = new Mutex();
        this.provider = provider;
    }

    // NOTE: Don't try de-allocate it, smart ass
    public User* getUser(string username)
    {
        // Lock
        this.usersLock.lock();

        // On exit
        scope(exit)
        {
            // Unlock
            this.usersLock.unlock();
        }

        // Check if such a user exists
        User** potentialUserPtrPtr = username in this.users;
        if(potentialUserPtrPtr == null)
        {
            return null;
        }
        else
        {
            return *potentialUserPtrPtr;
        }
    }

    private void addUser(string username)
    {
        // Lock
        this.usersLock.lock();

        // Create the user and insert it
        User* newUser = new User(username);
        this.users[username] = newUser;

        // Unlock
        this.usersLock.unlock();
    }

    private void removeUser(string username)
    {
        // Lock
        this.usersLock.lock();

        // Remove the user
        this.users.remove(username);

        // Unlock
        this.usersLock.unlock();
    }



    public bool authenticate(string username, string password)
    {
        logger.dbg("Authentication request for user '"~username~"' with password '"~password~"'");
        bool status;

        // TODO: Disallow the username from being empty

        status = this.provider.authenticate(username, password);
        if(status)
        {
            addUser(username);
            logger.info("Authenticated user '"~username~"'");
        }
        else
        {
            logger.error("Authentication failed for user '"~username~"'");
        }

        return status;
    }

    public static AuthManager create(Server server, AuthProvider provider = new DummyProvider())
    {
        AuthManager manager = new AuthManager(provider);
        manager.server = server;


        return manager;
    }
}