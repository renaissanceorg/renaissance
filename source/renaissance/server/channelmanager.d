module renaissance.server.channelmanager;

import renaissance.server.server : Server;
import std.container.slist : SList;
import core.sync.mutex : Mutex;

public struct Channel
{
    private SList!(string) members;
    private string name;
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
        Channel channelDesc = Channel();
        channelDesc.name = channel;
        this.channels[channel] = channelDesc;

        return true;
    }

    // NOTE: In future we could lock just the channel entry?
    // (once it has been found)
    public bool membershipJoin(string channel, string username)
    {
        // Lock channels map
        this.channelsLock.lock();

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
        
        // Search for membership, if already present, then an error
        foreach(string member; channelDesc.members)
        {
            if(member == username)
            {
                return false;
            }
        }

        // If not, then add user and it is fine
        channelDesc.members.insertAfter(channelDesc.members[], username);

        return true;
    }
}

unittest
{
    ChannelManager chanMan = new ChannelManager();

    // TODO: Add testing here

}