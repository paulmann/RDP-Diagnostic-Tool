<!-- Last Updated: 2026-04-01 | Version: 1.0.0 -->

# Performance

[[Home]] › Performance

This page covers GPU optimization, SMB Direct for User Profile Disks, QoS configuration, RDP over QUIC, and Azure Virtual Desktop tuning.

---

## 🎮 GPU / RemoteFX / vGPU Optimization

### GPU Memory Exhaustion Diagnosis

```powershell
# Monitor GPU memory usage per session
Get-Counter -Counter @(
  "\GPU Engine(*enqueue*)\Utilization Percentage",
  "\GPU Adapter Memory(*)\Dedicated Usage",
  "\GPU Adapter Memory(*)\Shared Usage"
) -SampleInterval 10 -Continuous

# Check RemoteFX adapter status
Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_Synthetic3DDisplayController |
  Select-Object ElementName, EnabledState, VRAMSizeBytes
```

### GPU Partitioning (GPU-P) for Hyper-V

```powershell
# Get available GPU partitions
Get-VMHostPartitionableGpu

# Assign GPU-P to a VM
Add-VMGpuPartitionAdapter -VMName "RDSH-01"
Set-VMGpuPartitionAdapter -VMName "RDSH-01" -MinPartitionVRAM 80000000 -MaxPartitionVRAM 200000000

# Verify assignment
Get-VMGpuPartitionAdapter -VMName "RDSH-01"
```

> [!NOTE]
> GPU-P requires Hyper-V on Windows Server 2022+ and a compatible GPU driver that supports SR-IOV or MCDM.

---

## 💾 SMB Direct for User Profile Disks (UPD)

SMB Direct uses RDMA to dramatically reduce UPD mount latency.

```powershell
# Verify RDMA capability
Get-NetAdapterRdma | Select-Object Name, Enabled

# Enable SMB Direct
Set-SmbClientConfiguration -EnableMultichannel $true
Set-SmbServerConfiguration -EnableMultiChannel $true

# Verify SMB Direct is active for UPD share
Get-SmbMultichannelConnection -ServerName "fileserver01" | Select-Object ServerName, ClientInterface, ServerInterface, Throughput

# Benchmark UPD access performance
$start = Get-Date
Mount-VHD -Path "\\fileserver01\UPDs\user01.vhdx" -ReadOnly
$mountTime = (Get-Date) - $start
Write-Host "UPD Mount Time: $($mountTime.TotalMilliseconds)ms" # Target: <500ms
```

---

## 📡 RDP over QUIC (Windows Server 2025+)

RDP over QUIC provides significant improvements over TCP for high-latency or lossy networks.

| Feature | RDP/TCP | RDP/QUIC |
|---------|---------|----------|
| Head-of-line blocking | Yes | No (stream multiplexing) |
| Connection migration | No | Yes |
| Forward Error Correction | Limited | Built-in |
| 0-RTT reconnect | No | Yes |
| Mobile/WiFi resilience | Poor | Excellent |

```powershell
# Enable RDP over QUIC (Windows Server 2025 / Windows 11 24H2+)
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
  -Name EnableRDPUDP -Value 1

# Verify QUIC transport is being used (check UDP 3389 activity)
Get-NetUDPEndpoint -LocalPort 3389
```

---

## ☁️ Azure Virtual Desktop Optimization

```powershell
# Set optimal screen capture rate for AVD
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
  -Name MaxMonitors -Value 4

# Configure Multimedia Redirection (MMR) for Teams/media
$mmrPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
Set-ItemProperty -Path $mmrPath -Name EnableMediaRedirection -Value 1

# Optimize compression for WAN
Set-ItemProperty -Path $mmrPath -Name VisualExperiencePolicy -Value 2
# 0=Let server decide, 1=Optimize for speed, 2=Optimize for experience
```

---

## ⚙️ Performance Tuning Matrix

| Scenario | Key Setting | Recommended Value |
|----------|-------------|-------------------|
| LAN / Datacenter | Color depth | 32bpp |
| WAN / VPN | Color depth | 16bpp, Enable compression |
| VDI (many users) | Dynamic resolution | Disabled |
| GPU workloads | RemoteFX | Enabled, H.264 AVC444 |
| Low bandwidth | Audio quality | Low (8 kHz, Mono) |
| High latency link | UDP transport | Enabled (QUIC on 2025+) |

---

**Next:** [[Enhancement-Roadmap]] →
