"""Custom Jinja2 filters for IPv4 address math."""
import struct
import socket


def _ip_to_int(ip):
    return struct.unpack("!I", socket.inet_aton(ip))[0]


def _int_to_ip(n):
    return socket.inet_ntoa(struct.pack("!I", n))


def ipv4_network(cidr):
    """Return the network address of a CIDR. '10.0.20.2/24' -> '10.0.20.0'"""
    ip, prefix = cidr.split("/")
    mask = (0xFFFFFFFF << (32 - int(prefix))) & 0xFFFFFFFF
    return _int_to_ip(_ip_to_int(ip) & mask)


def ipv4_nth(cidr, n):
    """Return the nth host address relative to the given IP. '192.168.2.0/16' | ipv4_nth(101) -> '192.168.2.101'"""
    ip, _ = cidr.split("/")
    return _int_to_ip(_ip_to_int(ip) + int(n))


def ipv4_nth_cidr(cidr, n):
    """Return the nth host address with the original prefix. '10.0.20.0/24' | ipv4_nth_cidr(101) -> '10.0.20.101/24'"""
    _, prefix = cidr.split("/")
    return ipv4_nth(cidr, n) + "/" + prefix


def ipv4_host(cidr):
    """Return just the host part of a CIDR. '10.0.20.2/24' -> '10.0.20.2'"""
    return cidr.split("/")[0]


def ipv4_prefixlen(cidr):
    """Return just the prefix length. '10.0.20.2/24' -> '24'"""
    return cidr.split("/")[1]


def normalize_zfs(entries):
    """Expand short ZFS dataset names to full zroot/jails/volumes/ paths."""
    result = []
    for entry in entries:
        e = dict(entry)
        if '/' not in e.get('name', ''):
            e['name'] = 'zroot/jails/volumes/' + e['name']
        result.append(e)
    return result


def normalize_nullfs(entries):
    """Expand short nullfs src names to full /usr/local/jails/volumes/ paths."""
    result = []
    for entry in entries:
        e = dict(entry)
        src = e.get('src', '')
        if not src.startswith('/'):
            e['src'] = '/usr/local/jails/volumes/' + src
        result.append(e)
    return result


class FilterModule(object):
    def filters(self):
        return {
            "ipv4_network": ipv4_network,
            "ipv4_nth": ipv4_nth,
            "ipv4_nth_cidr": ipv4_nth_cidr,
            "ipv4_host": ipv4_host,
            "ipv4_prefixlen": ipv4_prefixlen,
            "normalize_zfs": normalize_zfs,
            "normalize_nullfs": normalize_nullfs,
        }
