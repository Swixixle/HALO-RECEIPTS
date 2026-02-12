import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Key, Shield, Database, Clock } from "lucide-react";

const KEY_REGISTRY = [
  {
    key_id: "test-key-001",
    issuer_label: "AI Receipts Test",
    status: "ACTIVE",
    valid_from: "2024-01-01",
    valid_to: null,
    revoked_reason: null,
  },
  {
    key_id: "test-key-002-rotated",
    issuer_label: "AI Receipts Test (Rotated)",
    status: "ACTIVE",
    valid_from: "2024-06-01",
    valid_to: null,
    revoked_reason: null,
  },
  {
    key_id: "revoked-key-001",
    issuer_label: "AI Receipts Test",
    status: "REVOKED",
    valid_from: "2024-01-01",
    valid_to: "2024-03-15",
    revoked_reason: "Key compromise",
  },
  {
    key_id: "expired-key-001",
    issuer_label: "AI Receipts Test",
    status: "EXPIRED",
    valid_from: "2023-01-01",
    valid_to: "2023-12-31",
    revoked_reason: null,
  },
];

const RATE_LIMITS = [
  { endpoint: "Public verify", limit: "100/min", burst: "10/sec" },
  { endpoint: "Private verify", limit: "50/min", burst: "5/sec" },
];

const RESEARCH_EXCLUSIONS = [
  "No transcripts",
  "No receipt IDs",
  "No IPs",
  "No exact timestamps",
  "No PII values",
];

export default function Governance() {
  const getStatusBadge = (status: string) => {
    switch (status) {
      case "ACTIVE":
        return <Badge className="bg-green-600">ACTIVE</Badge>;
      case "REVOKED":
        return <Badge variant="destructive">REVOKED</Badge>;
      case "EXPIRED":
        return <Badge variant="secondary">EXPIRED</Badge>;
      default:
        return <Badge>{status}</Badge>;
    }
  };

  return (
    <div className="container mx-auto p-6 max-w-5xl">
      <h1 className="text-2xl font-bold mb-6" data-testid="text-governance-title">Governance</h1>

      <div className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Key className="w-5 h-5" />
              Key Registry
              <Badge variant="outline" className="ml-2">Ed25519 only</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table data-testid="table-key-registry">
              <TableHeader>
                <TableRow>
                  <TableHead>key_id</TableHead>
                  <TableHead>issuer_label</TableHead>
                  <TableHead>status</TableHead>
                  <TableHead>valid_from</TableHead>
                  <TableHead>valid_to</TableHead>
                  <TableHead>revoked_reason</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {KEY_REGISTRY.map((key) => (
                  <TableRow key={key.key_id} data-testid={`row-key-${key.key_id}`}>
                    <TableCell className="font-mono text-sm">{key.key_id}</TableCell>
                    <TableCell>{key.issuer_label}</TableCell>
                    <TableCell>{getStatusBadge(key.status)}</TableCell>
                    <TableCell>{key.valid_from}</TableCell>
                    <TableCell>{key.valid_to || "—"}</TableCell>
                    <TableCell>{key.revoked_reason || "—"}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="w-5 h-5" />
              Rate Limits
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table data-testid="table-rate-limits">
              <TableHeader>
                <TableRow>
                  <TableHead>Endpoint</TableHead>
                  <TableHead>Sustained Limit</TableHead>
                  <TableHead>Burst Limit</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {RATE_LIMITS.map((rl) => (
                  <TableRow key={rl.endpoint}>
                    <TableCell>{rl.endpoint}</TableCell>
                    <TableCell>{rl.limit}</TableCell>
                    <TableCell>{rl.burst}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Database className="w-5 h-5" />
              Research Export
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center gap-2 mb-4">
              <Shield className="w-4 h-4 text-muted-foreground" />
              <span className="text-sm text-muted-foreground">Consent-based only</span>
            </div>

            <div>
              <h4 className="font-medium mb-2">Explicit Exclusions</h4>
              <ul className="list-disc list-inside text-sm text-muted-foreground" data-testid="list-exclusions">
                {RESEARCH_EXCLUSIONS.map((exclusion) => (
                  <li key={exclusion}>{exclusion}</li>
                ))}
              </ul>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
