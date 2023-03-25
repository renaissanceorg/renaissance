module renaissance.exceptions.types;

import renaissance.exceptions.errors : ErrorType;
import std.conv : to;

public class RenaissanceException : Exception
{
    private ErrorType error;

    this(ErrorType error)
    {
        super(this.classinfo.name~": "~to!(string)(error));

        this.error = error;
    }

    public ErrorType getError()
    {
        return error;
    }
}