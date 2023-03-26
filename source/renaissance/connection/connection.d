module renaissance.connection.connection;

import davinci;
import core.thread : Thread;
import std.socket : Socket;
import renaissance.server;

public class Connection : Thread
{
    private Server associatedServer;
    private Socket clientSocket;

    private this(Server associatedServer, Socket clientSocket)
    {
        this.associatedServer = associatedServer;
        this.clientSocket = clientSocket;

        /* Set the worker function for the thread */
        super(&worker);
    }

    private void worker()
    {
        // TODO: Add worker function here
        while(true)
        {
            // TODO: Addn a tasky/tristanable queue managing thing with
            // ... socket here (probably just the latter)
            // ... which decodes using the `davinci` library
        }
    }

    /** 
     * Creates a new connection by associating a newly created
     * Connection instance with the provided Server and Socket
     * after which it will be added to the server's connection
     * queue, finally starting the thread that manages this connection
     *
     * TODO: Change this, the returning is goofy ah, I think perhaps
     * we should only construct it and then let `Server.addConnection()`
     * call start etc. - seeing that a Listener will call this
     *
     * Params:
     *   associatedServer = the server to associate with
     *   clientSocket = the associated socket backing the client
     *
     * Returns: the newly created Connection object
     */
    public static Connection newConnection(Server associatedServer, Socket clientSocket)
    {
        Connection conn = new Connection(associatedServer, clientSocket);

        /* Associate this connection with the provided server */
        associatedServer.addConnection(conn);

        /* Start the worker on a seperate thread */
        // new Thread(&worker);
        conn.start();


        return conn;
    }
}