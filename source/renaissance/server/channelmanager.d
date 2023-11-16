module renaissance.server.channelmanager;

import renaissance.server.server : Server;
import std.container.slist : SList;
import core.sync.mutex : Mutex;
import renaissance.logging;

public struct Channel
{
    private SList!(string) members;
    private string name;

    // TODO: Actually use this
    private Mutex channelLock;

    this(string channelName)
    {
        this.channelLock = new Mutex();
        this.name = channelName;
    }

    public bool hasMember(string username)
    {
        // Lock the channel
        this.channelLock.lock();

        // On exit
        scope(exit)
        {
            this.channelLock.unlock();
        }

        // Search for membership
        foreach(string member; this.members)
        {
            if(member == username)
            {
                return true;
            }
        }

        return false;
    }

    public bool removeMember(string username)
    {
        // Lock the channel
        this.channelLock.lock();

        // On exit
        scope(exit)
        {
            this.channelLock.unlock();
        }

        // Only remove if we have the member
        if(hasMember(username))
        {
            // Remove ourselves from the channel
            this.members.linearRemoveElement(username);

            return true;
        }
        // Error if not present
        else
        {
            return false;
        }
    }

    public bool addMember(string username)
    {
        // Lock the channel
        this.channelLock.lock();

        // On exit
        scope(exit)
        {
            this.channelLock.unlock();
        }

        // Only add if we are not yet present
        if(!hasMember(username))
        {
            // Remove ourselves from the channel
            this.members.insertAfter(this.members[], username);

            return true;
        }
        // Error if present already
        else
        {
            return false;
        }
    }
}

public final class ChannelManager
{
    private Server server;

    /** 
     * Map of channel names to
     * the respective channel
     * descriptors
     */
    private Channel[string] channels;
    private Mutex channelsLock;

    private this()
    {
        this.channelsLock = new Mutex();
    }

    public static ChannelManager create(Server server)
    {
        ChannelManager manager = new ChannelManager();
        manager.server = server;


        return manager;
    }

    private Channel* getChannel(string channel)
    {
        // Lock channels map
        this.channelsLock.lock();

        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }

        // Return a Channel* IF 
        // a value for that key exists
        return channel in this.channels;
    }

    private Channel* channelGet(string channel)
    {
        return getChannel(channel);
    }

    public bool channelExists(string channel)
    {
        return getChannel(channel) !is null;
    }

    public bool channelCreate(string channel)
    {
        // Lock channels map
        this.channelsLock.lock();

        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }

        if(channelExists(channel))
        {
            return false;
        }

        // Add a new channel descriptor
        Channel channelDesc = Channel(channel);
        this.channels[channel] = channelDesc;

        return true;
    }

    public string[] getChannelNames(ulong offset, ubyte limit)
    {
        // Lock channels map
        this.channelsLock.lock();

        // TODO: Move lock
        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }

        // TODO: Implement offset and limit

        // Adjust offset if it overshoots available
        // items
        if(!(offset < this.channels.length))
        {
            offset = 0;
        }

        ulong upperBound = offset+limit;
        logger.dbg("Upper bound (before): ", upperBound);

        if(upperBound >= this.channels.keys().length)
        {
            upperBound = this.channels.keys().length;
        }

        logger.dbg("Upper bound (after): ", upperBound);
        logger.dbg("Limit: ", limit);

        string[] channels = this.channels.keys()[offset..upperBound];

        return channels;
    }

    // NOTE: In future we could lock just the channel entry?
    // (once it has been found)
    public bool membershipJoin(string channel, string username)
    {
        // Lock channels map
        this.channelsLock.lock();

        // TODO: Move lock
        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }

        // Get the channel, check for our own membership
        Channel* channelDesc = channelGet(channel);

        // If not found, then that's an error
        if(channelDesc is null)
        {
            return false;
        }

        // TODO: Run any policies here

        // If not, then add user and it is fine
        //
        // Return value is whether or not
        // adding succeeded
        return channelDesc.addMember(username);

        // TODO: Run notification hooks here on the server
    }

    public bool membershipLeave(string channel, string username)
    {
        // Lock channels map
        this.channelsLock.lock();

        // TODO: Move lock
        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }

        // Get the channel, check for our own membership
        Channel* channelDesc = channelGet(channel);

        // If not found, then that's an error
        if(channelDesc is null)
        {
            return false;
        }
        
        // TODO: Run any policies here

        // If present, then leave
        //
        // Return value is whether or not
        // removal succeeded
        return channelDesc.removeMember(username);

        // TODO: Run notification hooks here on the server
    }
}

unittest
{
    ChannelManager chanMan = new ChannelManager();

    // TODO: Add testing here

}