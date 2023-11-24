module renaissance.connection.session;

import renaissance.connection.connection : Connection;
import renaissance.server.users : User;

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