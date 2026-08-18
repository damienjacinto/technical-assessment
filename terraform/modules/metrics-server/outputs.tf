output "addon_version" {
  description = "Resolved metrics-server addon version currently installed. Capture this into addon_version once stable, to pin it and make plans deterministic."
  value       = aws_eks_addon.metrics_server.addon_version
}
