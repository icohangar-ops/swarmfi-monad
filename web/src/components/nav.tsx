"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectWallet } from "@/components/connect-wallet";

const links = [
  { href: "/", label: "Dashboard" },
  { href: "/markets", label: "Markets" },
  { href: "/vaults", label: "Vaults" },
  { href: "/agents", label: "Agents" },
];

export function Nav() {
  const pathname = usePathname();
  return (
    <header className="border-b border-violet-500/20 bg-[#0a0614]/90 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-4">
        <div className="flex items-center gap-8">
          <Link href="/" className="text-lg font-semibold tracking-tight text-violet-200">
            SwarmFi
            <span className="ml-1 text-xs font-normal text-violet-400">on Monad</span>
          </Link>
          <nav className="hidden gap-1 sm:flex">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-lg px-3 py-1.5 text-sm transition ${
                  pathname === link.href
                    ? "bg-violet-600/30 text-white"
                    : "text-violet-300/80 hover:bg-violet-900/30 hover:text-white"
                }`}
              >
                {link.label}
              </Link>
            ))}
          </nav>
        </div>
        <ConnectWallet />
      </div>
    </header>
  );
}
