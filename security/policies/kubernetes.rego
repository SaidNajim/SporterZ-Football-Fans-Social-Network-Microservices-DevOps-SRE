package main

# Compliance rule: mutable tags are not allowed for workloads.
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Deployment %s uses mutable latest tag for container %s", [input.metadata.name, container.name])
}

# Compliance rule: avoid default namespace for application workloads.
deny[msg] {
  input.kind == "Deployment"
  not input.metadata.namespace
  msg := sprintf("Deployment %s does not define an explicit namespace", [input.metadata.name])
}

# Secure defaults advisory: CPU/memory limits should be declared.
warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("Deployment %s container %s should declare cpu limit", [input.metadata.name, container.name])
}

warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Deployment %s container %s should declare memory limit", [input.metadata.name, container.name])
}

# Secure defaults advisory: runAsNonRoot should be explicitly set.
warn[msg] {
  input.kind == "Deployment"
  not input.spec.template.spec.securityContext.runAsNonRoot
  msg := sprintf("Deployment %s should set pod securityContext.runAsNonRoot=true", [input.metadata.name])
}
