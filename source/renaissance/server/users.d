module renaissance.server.users;

import core.sync.mutex : Mutex;

public struct User
{
    private string username;
    private Mutex lock;

    @disable
    private this();

    this(string username)
    {
        this.lock = new Mutex();
    }

    // TODO: Disallow parameter less construction?
}


unittest
{
    User u = User("deavmi");
}