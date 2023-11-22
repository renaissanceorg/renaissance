module renaissance.logging;

import gogga;

public static __gshared GoggaLogger logger;

__gshared static  this()
{
    logger = new GoggaLogger();
    logger.enableDebug();
    logger.mode(GoggaMode.RUSTACEAN_SIMPLE);
}