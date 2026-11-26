#!/usr/bin/env python3
import subprocess, socket, concurrent.futures, ipaddress, re

def get_local_subnet():
    out = subprocess.check_output("ipconfig", shell=True, text=True, errors="ignore")
    ips = re.findall(r"IPv4[^:]*:\s*([\d.]+)", out)
    for ip in ips:
        if not ip.startswith("127."):
            return ip
    return None

def ping(ip):
    r = subprocess.run(["ping", "-n", "1", "-w", "200", ip],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return ip if r.returncode == 0 else None

def resolve_name(ip):
    try:
        return socket.gethostbyaddr(ip)[0]
    except Exception:
        return "unknown"

def scan():
    my_ip = get_local_subnet()
    if not my_ip:
        print("не удалось определить локальный IP"); return
    net = ipaddress.ip_network(my_ip + "/24", strict=False)
    print(f"[*] сканирую {net} ...\n")
    alive = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=64) as ex:
        for res in ex.map(ping, [str(h) for h in net.hosts()]):
            if res:
                alive.append(res)
    print(f"{'HOSTNAME':<30} {'IP':<16}")
    print("-" * 48)
    for ip in sorted(alive, key=lambda x: tuple(map(int, x.split('.')))):
        print(f"{resolve_name(ip):<30} {ip:<16}")

if __name__ == "__main__":
    scan()
