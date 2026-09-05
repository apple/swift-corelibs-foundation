// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

#if os(Windows)
import WinSDK

internal var FILE_ATTRIBUTE_DEVICE: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_DEVICE)
}

internal var FILE_ATTRIBUTE_DIRECTORY: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_DIRECTORY)
}

internal var FILE_ATTRIBUTE_HIDDEN: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_HIDDEN)
}

internal var FILE_ATTRIBUTE_READONLY: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_READONLY)
}

internal var FILE_ATTRIBUTE_REPARSE_POINT: DWORD {
    DWORD(WinSDK.FILE_ATTRIBUTE_REPARSE_POINT)
}

internal var FILE_FLAG_OPEN_REPARSE_POINT: DWORD {
    DWORD(WinSDK.FILE_FLAG_OPEN_REPARSE_POINT)
}

internal var GENERIC_WRITE: DWORD {
    DWORD(WinSDK.GENERIC_WRITE)
}

internal var MOVEFILE_COPY_ALLOWED: DWORD {
    DWORD(WinSDK.MOVEFILE_COPY_ALLOWED)
}

internal var MOVEFILE_REPLACE_EXISTING: DWORD {
    DWORD(WinSDK.MOVEFILE_REPLACE_EXISTING)
}

internal var MOVEFILE_WRITE_THROUGH: DWORD {
    DWORD(WinSDK.MOVEFILE_WRITE_THROUGH)
}
#endif
