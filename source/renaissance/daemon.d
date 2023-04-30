module renaissance.daemon;

import gogga;

public static __gshared GoggaLogger logger;

__gshared static  this()
{
    logger = new GoggaLogger();
}

void main()
{
    logger.info("Starting renaissance...");
}