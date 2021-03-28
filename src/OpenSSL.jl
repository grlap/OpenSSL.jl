module OpenSSL

using OpenSSL_jll
using BitFlags

"""
    [ ] Free BIO
    [ ] Free BIOMethod
    [ ] BIO_IO or BIO_JuliaIO, BIOStream method (callbacks)
"""

export TLSv12ClientMethod, SSLStream, eof, bytesavailable, read, unsafe_write,
    HTTP2_ALPN, UPDATE_HTTP2_ALPN

const Option{T} = Union{Nothing, T} where {T}

const HTTP2_ALPN = "\x02h2"
const UPDATE_HTTP2_ALPN = "\x02h2\x08http/1.1"

"""
    Lookup dictionary.
    Used to locate the Julia objects from C handlers.
"""
struct LookupDictionary{V}
    dictionary::Dict{Int64, V}
    lock::ReentrantLock
    id_counter::Threads.Atomic{Int64}

    function LookupDictionary{V}() where V
        println("LookupDictionary")
        return new(Dict{Int64, V}(), ReentrantLock(), Threads.Atomic{Int64}(1))
    end
end

"""
    Stores the object in the dictionary.
"""
function store!(lookup::LookupDictionary{V}, element::V)::Int64 where V
    element_id::Int64 = Threads.atomic_add!(lookup.id_counter, 1)

    lock(lookup.lock) do
        lookup.dictionary[element_id] = element
    end

    return element_id
end

"""
    Gets the element from the dictionary.
"""
function get(lookup::LookupDictionary{V}, user_data::Ptr{Cvoid})::Option{V} where V
    element_id::Int64 = Int64(user_data)

    lock(lookup.lock) do
        if (haskey(lookup.dictionary, element_id))
            element = lookup.dictionary[element_id]
            return element
        else
            return nothing
        end
    end
end

"""
    These are used in the following macros and are passed to BIO_ctrl().
"""
@enum(BIOCtrl::Cint,
    # opt - rewind/zero etc.
    BIO_CTRL_RESET = 1,
    # opt - are we at the eof.
    BIO_CTRL_EOF = 2,
    # opt - extra tit-bits.
    BIO_CTRL_INFO = 3,
    # man - set the 'IO' type.
    BIO_CTRL_SET = 4,
    # man - set the 'IO' type.
    BIO_CTRL_GET = 5,
    # opt - internal, used to signify change.
    BIO_CTRL_PUSH = 6,
    # opt - internal, used to signify change.
    BIO_CTRL_POP = 7,
    # man - set the 'close' on free.
    BIO_CTRL_GET_CLOSE = 8,
    # man - set the 'close' on free.
    BIO_CTRL_SET_CLOSE = 9,
    # opt - is their more data buffered.
    BIO_CTRL_PENDING = 10,
    # opt - 'flush' buffered output.
    BIO_CTRL_FLUSH = 11,
    # man - extra stuff for 'duped' BIO
    BIO_CTRL_DUP  = 12,
    # opt - number of bytes still to writes
    BIO_CTRL_WPENDING = 13,
    # opt - set callback function
    BIO_CTRL_SET_CALLBACK = 14,
    # opt - set callback function
    BIO_CTRL_GET_CALLBACK = 15,
    # BIO_f_buffer special
    BIO_CTRL_PEEK = 29,
    # BIO_s_file special,
    BIO_CTRL_SET_FILENAME = 30,
    # dgram BIO stuff:
    # BIO_s_file special.
    BIO_CTRL_DGRAM_CONNECT = 31,
    # allow for an externally connected socket to be passed in.
    BIO_CTRL_DGRAM_SET_CONNECTED = 32,
    # setsockopt, essentially.
    BIO_CTRL_DGRAM_SET_RECV_TIMEOUT = 33,
    # getsockopt, essentially.
    BIO_CTRL_DGRAM_GET_RECV_TIMEOUT = 34,
    # setsockopt, essentially.
    BIO_CTRL_DGRAM_SET_SEND_TIMEOUT = 35,
    # getsockopt, essentially
    BIO_CTRL_DGRAM_GET_SEND_TIMEOUT = 36,
    # flag whether the last.
    BIO_CTRL_DGRAM_GET_RECV_TIMER_EXP = 37,
    # I/O operation tiemd out.
    BIO_CTRL_DGRAM_GET_SEND_TIMER_EXP = 38,
    # set DF bit on egress packets
    BIO_CTRL_DGRAM_MTU_DISCOVER = 39,
    # as kernel for current MTU,
    BIO_CTRL_DGRAM_QUERY_MTU = 40,
    BIO_CTRL_DGRAM_GET_FALLBACK_MTU = 47,
    # get cached value for MTU.
    BIO_CTRL_DGRAM_GET_MTU = 41,
    # set cached value for MTU. Want to use this if asking the kernel fails.
    BIO_CTRL_DGRAM_SET_MTU = 42,
    # check whether the MTU was exceed in the previous write operation.
    BIO_CTRL_DGRAM_MTU_EXCEEDED = 43,
    BIO_CTRL_DGRAM_GET_PEER = 46,
    # Destination for the data.
    BIO_CTRL_DGRAM_SET_PEER = 44,
    # Next DTLS handshake timeout to adjust socket timeouts.
    BIO_CTRL_DGRAM_SET_NEXT_TIMEOUT = 45,
    BIO_CTRL_DGRAM_SET_DONT_FRAG = 48,
    BIO_CTRL_DGRAM_GET_MTU_OVERHEAD = 49,
    BIO_CTRL_DGRAM_SCTP_SET_IN_HANDSHAKE = 50,
    # SCTP stuff
    BIO_CTRL_DGRAM_SCTP_ADD_AUTH_KEY = 51,
    BIO_CTRL_DGRAM_SCTP_NEXT_AUTH_KEY = 52,
    BIO_CTRL_DGRAM_SCTP_AUTH_CCS_RCVD = 53,
    BIO_CTRL_DGRAM_SCTP_GET_SNDINFO = 60,
    BIO_CTRL_DGRAM_SCTP_SET_SNDINFO = 61,
    BIO_CTRL_DGRAM_SCTP_GET_RCVINFO = 62,
    BIO_CTRL_DGRAM_SCTP_SET_RCVINFO = 63,
    BIO_CTRL_DGRAM_SCTP_GET_PRINFO = 64,
    BIO_CTRL_DGRAM_SCTP_SET_PRINFO = 65,
    BIO_CTRL_DGRAM_SCTP_SAVE_SHUTDOWN = 70,
    # Set peek mode.
    BIO_CTRL_DGRAM_SET_PEEK_MODE = 71,
    # internal BIO:
    BIO_CTRL_SET_KTLS_SEND = 72,
    BIO_CTRL_SET_KTLS_SEND_CTRL_MSG = 74,
    BIO_CTRL_CLEAR_KTLS_CTRL_MSG = 75,
    BIO_CTRL_GET_KTLS_SEND = 73,
    BIO_CTRL_GET_KTLS_RECV = 76,
    BIO_CTRL_DGRAM_SCTP_WAIT_FOR_DRY = 77,
    BIO_CTRL_DGRAM_SCTP_MSG_WAITING = 78,
    # BIO_f_prefix controls.
    BIO_CTRL_SET_PREFIX = 79,
    BIO_CTRL_SET_INDENT = 80,
    BIO_CTRL_GET_INDENT = 81)

# Some values are reserved until OpenSSL 3.0.0 because they were previously
# included in SSL_OP_ALL in a 1.1.x release.
@bitflag SSLOptions::UInt64 begin
    # Disable Extended master secret
    SSL_OP_NO_EXTENDED_MASTER_SECRET = 0x00000001
    # Cleanse plaintext copies of data delivered to the application
    SSL_OP_CLEANSE_PLAINTEXT = 0x00000002
    # Allow initial connection to servers that don't support RI
    SSL_OP_LEGACY_SERVER_CONNECT = 0x00000004
    SSL_OP_TLSEXT_PADDING = 0x00000010
    SSL_OP_SAFARI_ECDHE_ECDSA_BUG = 0x00000040
    SSL_OP_IGNORE_UNEXPECTED_EOF = 0x00000080
    SSL_OP_DISABLE_TLSEXT_CA_NAMES = 0x00000200
    # In TLSv1.3 allow a non-(ec)dhe based kex_mode
    SSL_OP_ALLOW_NO_DHE_KEX = 0x00000400
    # Disable SSL 3.0/TLS 1.0 CBC vulnerability workaround that was added in
    # OpenSSL 0.9.6d.  Usually (depending on the application protocol) the
    # workaround is not needed.  Unfortunately some broken SSL/TLS
    # implementations cannot handle it at all, which is why we include it in
    # SSL_OP_ALL. Added in 0.9.6e
    SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS = 0x00000800
    # DTLS options
    SSL_OP_NO_QUERY_MTU = 0x00001000
    # Turn on Cookie Exchange (on relevant for servers)
    SSL_OP_COOKIE_EXCHANGE = 0x00002000
    # Don't use RFC4507 ticket extension
    SSL_OP_NO_TICKET = 0x00004000
    # Use Cisco's "speshul" version of DTLS_BAD_VER
    # (only with deprecated DTLSv1_client_method())
    SSL_OP_CISCO_ANYCONNECT = 0x00008000
    # As server, disallow session resumption on renegotiation
    SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION = 0x00010000
    # Don't use compression even if supported
    SSL_OP_NO_COMPRESSION = 0x00020000
    # Permit unsafe legacy renegotiation
    SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION = 0x00040000
    # Disable encrypt-then-mac
    SSL_OP_NO_ENCRYPT_THEN_MAC = 0x00080000
    # Enable TLSv1.3 Compatibility mode. This is on by default. A future version
    # of OpenSSL may have this disabled by default.
    SSL_OP_ENABLE_MIDDLEBOX_COMPAT = 0x00100000
    # Prioritize Chacha20Poly1305 when client does.
    # Modifies SSL_OP_CIPHER_SERVER_PREFERENCE
    SSL_OP_PRIORITIZE_CHACHA = 0x00200000
    # Set on servers to choose the cipher according to the server's preferences
    SSL_OP_CIPHER_SERVER_PREFERENCE =0x00400000
    # If set, a server will allow a client to issue a SSLv3.0 version number as
    # latest version supported in the premaster secret, even when TLSv1.0
    # (version 3.1) was announced in the client hello. Normally this is
    # forbidden to prevent version rollback attacks.
    SSL_OP_TLS_ROLLBACK_BUG = 0x00800000
    # Switches off automatic TLSv1.3 anti-replay protection for early data. This
    # is a server-side option only (no effect on the client).
    SSL_OP_NO_ANTI_REPLAY = 0x01000000
    SSL_OP_NO_SSLv3 = 0x02000000
    SSL_OP_NO_TLSv1 =  0x04000000
    SSL_OP_NO_TLSv1_2 = 0x08000000
    SSL_OP_NO_TLSv1_1 = 0x10000000
    SSL_OP_NO_TLSv1_3 = 0x20000000
    SSL_OP_NO_RENEGOTIATION = 0x40000000
    # Make server add server-hello extension from early version of cryptopro
    # draft, when GOST ciphersuite is negotiated. Required for interoperability
    # with CryptoPro CSP 3.x
    SSL_OP_CRYPTOPRO_TLSEXT_BUG = 0x80000000
end
const SSL_OP_NO_DTLSv1 = SSL_OP_NO_TLSv1
const SSL_OP_NO_DTLSv1_2 = SSL_OP_NO_TLSv1_2
const SSL_OP_NO_SSL_MASK = (SSL_OP_NO_SSLv3 | SSL_OP_NO_TLSv1 | SSL_OP_NO_TLSv1_1 | SSL_OP_NO_TLSv1_2|SSL_OP_NO_TLSv1_3)
const SSL_OP_NO_DTLS_MASK = (SSL_OP_NO_DTLSv1 | SSL_OP_NO_DTLSv1_2)

"""
    # SSL_OP_ALL: various bug workarounds that should be rather harmless.
    # This used to be 0x000FFFFFL before 0.9.7.
    # This used to be 0x80000BFFU before 1.1.1.
"""
const SSL_OP_ALL = (SSL_OP_CRYPTOPRO_TLSEXT_BUG|
                SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS|
                SSL_OP_LEGACY_SERVER_CONNECT|
                SSL_OP_TLSEXT_PADDING|
                SSL_OP_SAFARI_ECDHE_ECDSA_BUG)

"""
    OpenSSL init settings.
"""
@bitflag OpenSSLInitSettings::UInt32 begin
    OPENSSL_INIT_NO_LOAD_CRYPTO_STRINGS = 0x00000001
    OPENSSL_INIT_LOAD_CRYPTO_STRINGS = 0x00000002
    OPENSSL_INIT_ADD_ALL_CIPHERS = 0x00000004
    OPENSSL_INIT_ADD_ALL_DIGESTS = 0x00000008
    OPENSSL_INIT_NO_ADD_ALL_CIPHERS = 0x00000010
    OPENSSL_INIT_NO_ADD_ALL_DIGESTS = 0x00000020
    OPENSSL_INIT_LOAD_CONFIG = 0x00000040
    OPENSSL_INIT_NO_LOAD_CONFIG = 0x00000080
    OPENSSL_INIT_ASYNC = 0x00000100
    OPENSSL_INIT_ENGINE_RDRAND = 0x00000200
    OPENSSL_INIT_ENGINE_DYNAMIC = 0x00000400
    OPENSSL_INIT_ENGINE_OPENSSL = 0x00000800
    OPENSSL_INIT_ENGINE_CRYPTODEV = 0x00001000
    OPENSSL_INIT_ENGINE_CAPI = 0x00002000
    OPENSSL_INIT_ENGINE_PADLOCK = 0x00004000
    OPENSSL_INIT_ENGINE_AFALG = 0x00008000
    OPENSSL_INIT_ATFORK = 0x00020000
    OPENSSL_INIT_NO_ATEXIT = 0x00080000
    OPENSSL_INIT_NO_LOAD_SSL_STRINGS = 0x00100000
    OPENSSL_INIT_LOAD_SSL_STRINGS = 0x00200000
end

const OPENSSL_INIT_SSL_DEFAULT = (OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS)

"""
    BIO.
"""
mutable struct BIO
    bio::Ptr{Cvoid}
end

function get_data(bio::BIO)::Ptr{Cvoid}
    bio_id = ccall((:BIO_get_data, libcrypto),
        Ptr{Cvoid},
        (BIO,),
        bio)
    return Ptr{Cvoid}(bio_id)
end

"""
    #TODO
"""
mutable struct BIOStream{S <: IO} <: IO

end

const BIO_IO = LookupDictionary{IO}()

"""
    BIO callbacks.
"""

"""
    Called to initalize new BIO object.
"""
function on_bio_create(bio::BIO)::Cint
    println("on_bio_create $(bio)")

    # Initalize BIO.
    ccall((:BIO_set_init, libcrypto),
        Cvoid,
        (BIO, Cint),
        bio,
        0)

    ccall((:BIO_set_data, libcrypto),
        Cvoid,
        (BIO, Cint),
        bio,
        C_NULL)

    return Cint(1)
end

function on_bio_destroy(bio::BIO)::Cint
    println("on_bio_destroy $(bio)")
    return Cint(0)
end

function on_bio_read(bio::BIO, out::Ptr{Cchar}, outlen::Cint)::Cint
    println("on_bio_read $(bio) out_buffer:$(out) out_length:$(outlen)")

    io = get(BIO_IO, get_data(bio))
    eof(io)
    available_bytes = bytesavailable(io)

    println("available to read: $(available_bytes)")
    outlen = min(outlen, available_bytes)

    unsafe_read(io, out, outlen)
    println("read from: $(io) in_buffer:$(out) in_length:$(outlen)")

    return outlen
end

function on_bio_write(bio::BIO, in::Ptr{Cchar}, inlen::Cint)::Cint
    println("on_bio_write $(bio) id:$(get_data(bio))")

    io = get(BIO_IO, get_data(bio))
    written = unsafe_write(io, in, inlen)
    println("written: $(written) to: $(io) in_buffer:$(in) in_length:$(inlen)")

    return Cint(written)
end

function on_bio_puts(bio::BIO, in::Ptr{Cchar})::Cint
    println("on_bio_puts $(bio)")

    return Cint(0)
end

function on_bio_ctrl(bio::BIO, cmd::BIOCtrl, num::Int64, ptr::Ptr{Cvoid})::Int64
    println("on_bio_ctrl $(bio) cmd:$(cmd)")

    return 1
end

"""
    BIO write
"""
function Base.unsafe_write(bio::BIO, out_buffer::Ptr{UInt8}, out_length::Int)
    println("==> bio_unsafe_write: $(bio) ptr:$(out_buffer) len:$(out_length)")

    result = ccall((:BIO_write, libcrypto),
        Cint,
        (BIO, Ptr{Cvoid}, Cint),
        bio,
        out_buffer,
        out_length)

    println("<== bio_unsafe_write: $(bio) result:$(result)")
    return result
end

"""
    OpenSSL BIOMethod.
"""
mutable struct BIOMethod
    bio_meth::Ptr{Cvoid}

    function BIOMethod(bio_meth::Ptr{Cvoid})
        return new(bio_meth)
    end

    function BIOMethod(bio_type::String)
        println("new BIOMethod $(bio_type)")
        bio_meth_index = ccall((:BIO_get_new_index, libcrypto),
            Cint,
            ())
        @show bio_meth_index

        bio_meth = ccall((:BIO_meth_new, libcrypto),
            Ptr{Cvoid},
            (Cint, Cstring,),
            bio_meth_index,
            bio_type)

        result::Cint = ccall((:BIO_meth_set_create, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_create_ptr)

        result = ccall((:BIO_meth_set_destroy, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_destroy_ptr)

        result = ccall((:BIO_meth_set_read, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_read_ptr)

        result = ccall((:BIO_meth_set_write, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_write_ptr)

        result = ccall((:BIO_meth_set_puts, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_puts_ptr)

        result = ccall((:BIO_meth_set_ctrl, libcrypto),
            Cint,
            (Ptr{Cvoid}, Ptr{Cvoid}),
            bio_meth,
            OPEN_SSL_INIT.x.on_bio_ctrl_ptr)

"""
    BIO_meth_set_create(methods_bufferevent, bio_bufferevent_new);
    BIO_meth_set_destroy(methods_bufferevent, bio_bufferevent_free);
"""
        return new(bio_meth)
    end
end

"""
    Creates a file descriptor BIO method.
"""
function BIOMethod_fd()::BIOMethod
    bio_meth = ccall((:BIO_s_fd, libcrypto),
        Ptr{Cvoid},
        ())

    return BIOMethod(bio_meth)
end

"""
    Cretes a memory BIO method.
"""
function BIOMethod_mem()::BIOMethod
    bio_meth = ccall((:BIO_s_mem, libcrypto),
        Ptr{Cvoid},
        ())

    return BIOMethod(bio_meth)
end

function free(bioMethod::BIOMethod)
    println("free BIOMethod")
    ccall((:BIO_meth_free, libcrypto),
            Ptr{Cvoid},
            (BIOMethod,),
            bioMethod)
    bioMethod.bio = C_NULL
end

"""
    Creates BIO on IO object.
"""
function BIO(io::IO)
    println("new BIO $(io)")

    bio =  ccall((:BIO_new, libcrypto),
        Ptr{Cvoid},
        (BIOMethod,),
        BIO_METHOD.x)
    bio = BIO(bio)

    # Store in the lookup table.
    bio_id = store!(BIO_IO, io)

    # Store the lookup id in the OpenSSL bio object.
    ccall((:BIO_set_data, libcrypto),
        Cvoid,
        (BIO, Ptr{Cvoid}),
        bio,
        Ptr{Cvoid}(bio_id))

    # Mark BIO as initalized.
    ccall((:BIO_set_init, libcrypto),
        Cvoid,
        (BIO, Cint),
        bio,
        1)

    ccall((:BIO_set_shutdown, libcrypto),
        Cvoid,
        (BIO, Cint),
        bio,
        0)

    println("$(bio) $(bio_id)")
    return bio
end

"""
    Creates BIO for given BIOMethod.
"""
function BIO(bio_method::BIOMethod)
    bio =  ccall((:BIO_new, libcrypto),
        Ptr{Cvoid},
        (BIOMethod,),
        bio_method)
    bio = BIO(bio)

    return bio
end

function verify(bio::BIO)
    println("verify: $(bio)")

    looked_up_bio = get(BIO_IO, get_data(bio))
    return bio == looked_up_bio
end

"""
    SSLMethod.
    TLSv12ClientMethod.
"""
mutable struct SSLMethod
    ssl_method::Ptr{Cvoid}
end

function TLSv12ClientMethod()
    ssl_method = ccall((:TLSv1_2_client_method, libssl),
            Ptr{Cvoid},
            ())
    return SSLMethod(ssl_method)
end

"""
    This is the global context structure which is created by a server or client once per program life-time
    and which holds mainly default values for the SSL structures which are later created for the connections.
"""
mutable struct SSLContext
    ssl_ctx::Ptr{Cvoid}

    function SSLContext(ssl_method::SSLMethod)
        ssl_ctx = ccall((:SSL_CTX_new, libssl),
                Ptr{Cvoid},
                (SSLMethod,),
                ssl_method)
        context = new(ssl_ctx)
        finalizer(free, context)
        return context
    end
end

"""
    Sets the (external) protocol behaviour of the SSL library.
"""
function set_options(ssl_context::SSLContext, options::SSLOptions)
    result = ccall((:SSL_CTX_set_options, libssl),
                UInt64,
                (SSLContext, UInt64,),
                ssl_context,
                options)

    return result
end

"""
    Configures TLS ALPN (Application-Layer Protocol Negotiation).
""" 
function set_alpn(ssl_context::SSLContext, protocol_list::String)
    result = ccall((:SSL_CTX_set_alpn_protos, libssl),
        Cint,
        (SSLContext, Ptr{UInt8}, UInt32),
        ssl_context,
        pointer(protocol_list),
        length(protocol_list))
    println("set_alpn: $(protocol_list) $(result)")
end

function free(ssl_context::SSLContext)
    println("free $(ssl_context)")
    ccall((:SSL_CTX_free, libssl),
            Ptr{Cvoid},
            (SSLContext,),
            ssl_context)
    ssl_context.ssl_ctx = C_NULL
end

"""
    SSL structure for a connection.
"""
mutable struct SSL
    ssl::Ptr{Cvoid}

    function SSL(ssl_context::SSLContext, read_bio::BIO, write_bio::BIO)::SSL
        ssl = ccall((:SSL_new, libssl),
            Ptr{Cvoid},
            (SSLContext,),
            ssl_context)
        ssl = new(ssl)

        ccall((:SSL_set_bio, libssl),
            Ptr{Cvoid},
            (SSL, BIO, BIO),
            ssl,
            read_bio,
            write_bio)

        return ssl
    end
end

function connect(ssl::SSL)::Cint
    result = ccall((:SSL_connect, libssl),
        Cint,
        (SSL,),
        ssl)

    ccall((:SSL_set_read_ahead, libssl),
        Ptr{Cvoid},
        (SSL, Cint),
        ssl,
        1)

    return result
end

function get_error(ssl::SSL, ret::Cint)::Cint
    result = ccall((:SSL_get_error, libssl),
        Cint,
        (SSL, Cint),
        ssl,
        ret)
    return result
end

function get_error()::Int64
    result = ccall((:ERR_get_error, libcrypto),
        Int64,
        ())

    #err_string = Vector{UInt8}(1024)

    return result
end

"""
    SSLStream.
"""
struct SSLStream <: IO
    ssl::SSL
    lock::ReentrantLock

    function SSLStream(ssl::SSL)
        return new(ssl, ReentrantLock())
    end
end

"""
    Force read operation on the stream. This will update the pending bytes.
"""
function force_read_buffer(ssl_stream::SSLStream)
    has_pending = ccall((:SSL_has_pending, libssl),
        Cint,
        (SSL,),
        ssl_stream.ssl)

    # If there is no data in the buffer, peek and force the first read.
    in_buffer = Vector{UInt8}(undef, 1)
    read_count = ccall((:SSL_peek, libssl),
        Cint,
        (SSL, Ptr{Int8}, Cint),
        ssl_stream.ssl,
        pointer(in_buffer),
        length(in_buffer))
end

function Base.unsafe_write(ssl_stream::SSLStream, in_buffer::Ptr{UInt8}, in_length::UInt)
    println("==> ssl_unsafe_write: $(ssl_stream) ptr:$(in_buffer) len:$(in_length)")

    write_count::Int = 0

    write_count = ccall((:SSL_write, libssl),
        Cint,
        (SSL, Ptr{Cvoid}, Cint),
        ssl_stream.ssl,
        in_buffer,
        in_length)

    println("<== ssl_unsafe_write: $(ssl_stream) written:$(write_count)")
    return write_count
end

"""
    Read from the SSL stream.
"""
function Base.read(ssl_stream::SSLStream, in_length::Int32)::Vector{UInt8}
    return read(ssl_stream)
end

function Base.read(ssl_stream::SSLStream)::Vector{UInt8}
    println("[ ] Base.read")
    lock(ssl_stream.lock) do
        println("  => Base.read =>")

        # Force first read, that will update the pending bytes.
        force_read_buffer(ssl_stream)

        has_pending = ccall((:SSL_has_pending, libssl),
            Cint,
            (SSL,),
            ssl_stream.ssl)

        pending_count = ccall((:SSL_pending, libssl),
            Cint,
            (SSL,),
            ssl_stream.ssl)

        # Allocate read buffer and copy the data to it.
        read_buffer = Vector{UInt8}(undef, pending_count)

        if (pending_count != 0)
            read_count = ccall((:SSL_read, libssl),
                Cint,
                (SSL, Ptr{Int8}, Cint),
                ssl_stream.ssl,
                pointer(read_buffer),
                pending_count)

            resize!(read_buffer, read_count)
        end

        return read_buffer
    end
end

function Base.bytesavailable(ssl_stream::SSLStream)::Cint
    println("=> bytesavailable ssl_stream")
    force_read_buffer(ssl_stream)

    has_pending = ccall((:SSL_has_pending, libssl),
        Cint,
        (SSL,),
        ssl_stream.ssl)

    pending_count = ccall((:SSL_pending, libssl),
        Cint,
        (SSL,),
        ssl_stream.ssl)

    println("<<= bytesavailable ssl_stream $(pending_count)")

    return pending_count
end

function Base.eof(ssl_stream::SSLStream)::Bool
    println("==> eof ssl_stream")
    force_read_buffer(ssl_stream)

    has_pending = ccall((:SSL_has_pending, libssl),
        Cint,
        (SSL,),
        ssl_stream.ssl)

    result = has_pending == 0
    println("<== eof ssl_stream $(has_pending)")

    return result
end

"""
    X509 Name
"""
mutable struct X509Name
    x509_name::Ptr{Cvoid}
end

function free(x509_name::X509Name)
    println("free $(x509_name)")

    ccall((:X509_NAME_free, libssl),
        Cvoid,
        (X509Name,),
        x509_name)

    x509_name.x509_name = C_NULL
end

"""
    X509Name to string.
"""
function string(x509_name::X509Name)::String
    name_ptr = ccall((:X509_NAME_oneline, libcrypto),
        Cstring,
        (X509Name, Ptr{UInt8}, Cint,),
        x509_name,
        C_NULL,
        0)

    str = unsafe_string(name_ptr)

    name_ptr = ccall((:CRYPTO_free, libcrypto),
        Cvoid,
        (Cstring,),
        name_ptr)

    return str
end

"""
    X509 Certificate.
"""
mutable struct X509Certificate
    x509::Ptr{Cvoid}

    function X509Certificate()
        x509 = ccall((:X509_new, libssl), Ptr{Cvoid}, ())
        x509 = new(x509)

        finalizer(free, x509)
        return x509
    end

    """
        Creates a X509 certifcate from PEM string.
    """
    function X509Certificate(in_string::AbstractString)::X509Certificate
        @show in_string
        @show IOBuffer(in_string)

        # Create a BIO and write the PEM string.
        bio = BIO(OpenSSL.BIOMethod_mem())
        unsafe_write(bio, pointer(in_string), length(in_string))

        x509 = ccall((:PEM_read_bio_X509, libcrypto),
            Ptr{Cvoid},
            (BIO, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
            bio,
            C_NULL,
            C_NULL,
            C_NULL)

        x509_cert = new(x509)

        finalizer(free, x509_cert)
        return x509_cert
    end
end

function free(x509_cert::X509Certificate)
    println("free $(x509_cert)")

    ccall((:X509_free, libcrypto),
            Ptr{Cvoid},
            (X509Certificate,),
            x509_cert)
    x509_cert.x509 = C_NULL
end

function get_subject_name(x509_cert::X509Certificate)
    x509_name = ccall((:X509_get_subject_name, libcrypto),
        Ptr{Cvoid},
        (X509Certificate,),
        x509_cert)

    # x509_name is an internal pointer and must not be freed.
    x509_name = X509Name(x509_name)

    return x509_name
end

"""
    Crypto Init.
    Initialize OpenSSL library.
"""
mutable struct OpenSSLInit
    result::Bool
    on_bio_create_ptr::Ptr{Nothing}
    on_bio_destroy_ptr::Ptr{Nothing}
    on_bio_read_ptr::Ptr{Nothing}
    on_bio_write_ptr::Ptr{Nothing}
    on_bio_puts_ptr::Ptr{Nothing}
    on_bio_ctrl_ptr::Ptr{Nothing}

    function OpenSSLInit()
        println("=> [OpenSSL Init]")

        result = ccall((:OPENSSL_init_crypto, libcrypto),
            Cint,
            (Cint, Ptr{Cvoid}),
            Cint(OPENSSL_INIT_LOAD_CRYPTO_STRINGS | OPENSSL_INIT_ASYNC),
            C_NULL)
        @show result

        result = ccall((:OPENSSL_init_ssl, libssl),
            Cint,
            (Cint, Ptr{Cvoid}),
            Cint(OPENSSL_INIT_LOAD_SSL_STRINGS),
            C_NULL)
            @show result

        # Callbacks
        on_bio_create_ptr = @cfunction on_bio_create Cint (BIO,)
        on_bio_destroy_ptr = @cfunction on_bio_destroy Cint (BIO,)
        on_bio_read_ptr = @cfunction on_bio_read Cint (BIO, Ptr{Cchar}, Cint)
        on_bio_write_ptr = @cfunction on_bio_write Cint (BIO, Ptr{Cchar}, Cint)
        on_bio_puts_ptr = @cfunction on_bio_puts Cint (BIO, Ptr{Cchar})
        on_bio_ctrl_ptr = @cfunction on_bio_ctrl Int64 (BIO, BIOCtrl, Int64, Ptr{Cvoid})
        
        return new(
            result,
            on_bio_create_ptr,
            on_bio_destroy_ptr,
            on_bio_read_ptr,
            on_bio_write_ptr,
            on_bio_puts_ptr,
            on_bio_ctrl_ptr)
    end
end

const OPEN_SSL_INIT = Ref{OpenSSLInit}()
const BIO_METHOD = Ref{BIOMethod}()

"""
    Initalize module.
"""
function __init__()
    println("$(@__MODULE__)::__init")
    OPEN_SSL_INIT.x = OpenSSLInit()
    BIO_METHOD.x = BIOMethod("BIO_TYPE_LIBEVENT")

    @show get_error()
end

end # OpenSSL module

