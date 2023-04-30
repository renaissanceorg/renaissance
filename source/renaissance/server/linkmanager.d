module renaissance.server.linkmanager;

import renaissance.server;

public class LinkManager
{
    private Server server;

    private this()
    {

    }

    public static LinkManager createManager(Server server)
    {
        LinkManager manager = new LinkManager();
        manager.server = server;


        return manager;
    }
}