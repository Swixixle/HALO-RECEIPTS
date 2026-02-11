import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Upload, CheckCircle, XCircle, AlertCircle } from "lucide-react";
import { apiRequest } from "@/lib/queryClient";
import { HaloHeader } from "@/components/halo-header";

interface VerificationResult {
  verification_status: string;
  hash_match: boolean;
  signature_status: string;
  chain_status: string;
  receipt_id: string;
}

interface ProofPackResult {
  schema: "ai-receipt/proof-pack/1.0";
  receipt_id: string;
  verification_status: string;
  integrity: {
    hash_match: boolean;
    computed_hash_sha256: string;
    expected_hash_sha256: string;
  };
  signature: {
    status: string;
  };
  chain: {
    status: string;
  };
}

export default function Verify() {
  const [capsuleJson, setCapsuleJson] = useState("");
  const [receiptId, setReceiptId] = useState("");
  const [publicOnly, setPublicOnly] = useState(false);
  const [error, setError] = useState<{ code: number; message: string } | null>(null);

  const verifyPrivateMutation = useMutation({
    mutationFn: async (capsule: object) => {
      const res = await fetch("/api/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(capsule),
      });
      if (!res.ok) {
        const err = new Error("Verification failed") as Error & { status: number; retryAfter?: string };
        err.status = res.status;
        err.retryAfter = res.headers.get("Retry-After") || undefined;
        throw err;
      }
      return res.json();
    },
    onError: (err: Error & { status?: number; retryAfter?: string }) => {
      const status = err.status || 500;
      const retryAfter = (err as any).retryAfter;
      if (status === 413) {
        setError({ code: 413, message: "Capsule exceeds size cap. Split transcript or use redacted mode." });
      } else if (status === 429) {
        const timestamp = retryAfter || new Date(Date.now() + 60000).toISOString();
        setError({ code: 429, message: `Rate limited. Retry after ${timestamp}.` });
      } else if (status === 401 || status === 403) {
        setError({ code: status, message: "Private endpoints require x-api-key." });
      } else {
        setError({ code: status, message: err.message || "Verification failed" });
      }
    },
    onSuccess: () => {
      setError(null);
    },
  });

  const proofPublicMutation = useMutation({
    mutationFn: async (id: string) => {
      const res = await fetch(`/api/public/receipts/${encodeURIComponent(id)}/proof`);
      if (!res.ok) {
        const err = new Error("Verification failed") as Error & { status: number; retryAfter?: string };
        err.status = res.status;
        err.retryAfter = res.headers.get("Retry-After") || undefined;
        throw err;
      }
      return res.json();
    },
    onError: (err: Error & { status?: number; retryAfter?: string }) => {
      const status = err.status || 500;
      const retryAfter = (err as any).retryAfter;
      if (status === 404) {
        setError({ code: 404, message: "Receipt not found." });
      } else if (status === 429) {
        const timestamp = retryAfter || new Date(Date.now() + 60000).toISOString();
        setError({ code: 429, message: `Rate limited. Retry after ${timestamp}.` });
      } else {
        setError({ code: status, message: err.message || "Verification failed" });
      }
    },
    onSuccess: () => {
      setError(null);
    },
  });

  const handleVerify = () => {
    setError(null);
    if (publicOnly) {
      if (!receiptId.trim()) {
        setError({ code: 400, message: "Receipt ID is required" });
        return;
      }
      proofPublicMutation.mutate(receiptId.trim());
    } else {
      try {
        const parsed = JSON.parse(capsuleJson);
        verifyPrivateMutation.mutate(parsed);
      } catch {
        setError({ code: 400, message: "Invalid JSON format" });
      }
    }
  };

  const isPending = verifyPrivateMutation.isPending || proofPublicMutation.isPending;

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (event) => {
        setCapsuleJson(event.target?.result as string);
      };
      reader.readAsText(file);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "VERIFIED":
        return <Badge className="bg-green-600" data-testid="badge-verified">VERIFIED</Badge>;
      case "PARTIALLY_VERIFIED":
        return <Badge className="bg-yellow-600" data-testid="badge-partial">PARTIALLY VERIFIED</Badge>;
      case "UNVERIFIED":
        return <Badge variant="destructive" data-testid="badge-unverified">UNVERIFIED</Badge>;
      default:
        return <Badge variant="secondary">{status}</Badge>;
    }
  };

  const privateResult = verifyPrivateMutation.data as VerificationResult | undefined;
  const proofResult = proofPublicMutation.data as ProofPackResult | undefined;
  
  const result = privateResult ? {
    verification_status: privateResult.verification_status,
    hash_match: privateResult.hash_match,
    signature_status: privateResult.signature_status,
    chain_status: privateResult.chain_status,
    receipt_id: privateResult.receipt_id,
  } : proofResult ? {
    verification_status: proofResult.verification_status,
    hash_match: proofResult.integrity.hash_match,
    signature_status: proofResult.signature.status,
    chain_status: proofResult.chain.status,
    receipt_id: proofResult.receipt_id,
  } : undefined;

  return (
    <div>
      {result && (
        <HaloHeader
          killSwitchEngaged={false}
          verificationStatus={result.verification_status as "VERIFIED" | "PARTIALLY_VERIFIED" | "UNVERIFIED"}
          transcriptMode="full"
        />
      )}
      <div className="container mx-auto p-6 max-w-4xl">
        <h1 className="text-2xl font-bold mb-6" data-testid="text-verify-title">Verify</h1>

      <Card className="mb-6">
        <CardHeader>
          <CardTitle>{publicOnly ? "Public Proof Lookup" : "Submit Receipt Capsule"}</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-2 mb-4">
            <Switch
              id="public-only"
              checked={publicOnly}
              onCheckedChange={setPublicOnly}
              data-testid="switch-public-only"
            />
            <Label htmlFor="public-only">Public proof (receipt id only)</Label>
          </div>

          {publicOnly ? (
            <div>
              <Label htmlFor="receipt-id-input">Receipt ID</Label>
              <Input
                id="receipt-id-input"
                data-testid="input-receipt-id"
                placeholder="Enter receipt ID"
                value={receiptId}
                onChange={(e) => setReceiptId(e.target.value)}
                className="font-mono"
              />
              <p className="text-xs text-muted-foreground mt-1">
                Public endpoint: no API key required
              </p>
            </div>
          ) : (
            <>
              <div>
                <Label htmlFor="capsule-input">Paste JSON Capsule</Label>
                <Textarea
                  id="capsule-input"
                  data-testid="input-capsule-json"
                  placeholder='{"schema": "ai-receipt/1.0", ...}'
                  value={capsuleJson}
                  onChange={(e) => setCapsuleJson(e.target.value)}
                  className="font-mono text-sm min-h-[200px]"
                />
              </div>

              <div className="flex items-center gap-4">
                <Label htmlFor="file-upload" className="cursor-pointer">
                  <div className="flex items-center gap-2 px-4 py-2 border rounded-md hover-elevate">
                    <Upload className="w-4 h-4" />
                    Upload JSON file
                  </div>
                  <input
                    id="file-upload"
                    type="file"
                    accept=".json"
                    className="hidden"
                    onChange={handleFileUpload}
                    data-testid="input-file-upload"
                  />
                </Label>
              </div>
              <p className="text-xs text-muted-foreground">
                Private endpoint: requires x-api-key
              </p>
            </>
          )}

          <Button
            onClick={handleVerify}
            disabled={publicOnly ? !receiptId : !capsuleJson || isPending}
            data-testid="button-verify"
          >
            {isPending ? "Verifying..." : "Verify"}
          </Button>
        </CardContent>
      </Card>

      {error && (
        <Card className="mb-6 border-destructive">
          <CardContent className="pt-6">
            <div className="flex items-center gap-2 text-destructive" data-testid="text-error">
              <XCircle className="w-5 h-5" />
              <span className="font-medium">Error {error.code}</span>
            </div>
            <p className="mt-2">{error.message}</p>
          </CardContent>
        </Card>
      )}

      {result && (
        <div className="space-y-4">
          <div className="flex items-center gap-4 mb-6">
            <span className="font-semibold">Verification Result:</span>
            {getStatusBadge(result.verification_status)}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card data-testid="card-hash">
              <CardHeader className="pb-2">
                <CardTitle className="text-base flex items-center gap-2">
                  {result.hash_match ? (
                    <CheckCircle className="w-4 h-4 text-green-600" />
                  ) : (
                    <XCircle className="w-4 h-4 text-destructive" />
                  )}
                  Hash
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  {result.hash_match ? "Match" : "Mismatch"}
                </p>
                <p className="text-xs text-muted-foreground mt-1">SHA-256 / c14n-v1</p>
              </CardContent>
            </Card>

            <Card data-testid="card-signature">
              <CardHeader className="pb-2">
                <CardTitle className="text-base flex items-center gap-2">
                  {result.signature_status === "VALID" ? (
                    <CheckCircle className="w-4 h-4 text-green-600" />
                  ) : result.signature_status === "NO_SIGNATURE" ? (
                    <AlertCircle className="w-4 h-4 text-yellow-600" />
                  ) : (
                    <XCircle className="w-4 h-4 text-destructive" />
                  )}
                  Signature
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">{result.signature_status}</p>
                <p className="text-xs text-muted-foreground mt-1">Ed25519</p>
              </CardContent>
            </Card>

            <Card data-testid="card-chain">
              <CardHeader className="pb-2">
                <CardTitle className="text-base flex items-center gap-2">
                  {result.chain_status === "LINKED" || result.chain_status === "GENESIS" ? (
                    <CheckCircle className="w-4 h-4 text-green-600" />
                  ) : result.chain_status === "NOT_CHECKED" ? (
                    <AlertCircle className="w-4 h-4 text-yellow-600" />
                  ) : (
                    <XCircle className="w-4 h-4 text-destructive" />
                  )}
                  Chain
                </CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">{result.chain_status}</p>
              </CardContent>
            </Card>
          </div>

          <p className="text-xs text-muted-foreground mt-4">
            This status reflects cryptographic and chain checks only.
          </p>
        </div>
      )}
      </div>
    </div>
  );
}
