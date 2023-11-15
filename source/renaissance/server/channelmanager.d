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
    }

    public void membershipJoin(string channel, string username)
    {
        // Lock channels map
        this.channelsLock.lock();

        // On exit
        scope(exit)
        {
            // Unlock channels map
            this.channelsLock.unlock();
        }


        
    }
}