#include "mts300.h"

configuration PhotoTempDeviceC
{
  provides interface Resource as PhotoResource[uint8_t client];
  provides interface Resource as TempResource[uint8_t client];
  provides interface Read<uint16_t> as ReadPhoto[uint8_t client];
  provides interface Read<uint16_t> as ReadTemp[uint8_t client];
}
implementation
{
  components MicaBusC, PhotoTempP,
    new RoundRobinArbiterC(UQ_PHOTOTEMP_RESOURCE) as SharingArbiter,
    new RoundRobinArbiterC(UQ_PHOTO_RESOURCE) as PhotoArbiter,
    new RoundRobinArbiterC(UQ_TEMP_RESOURCE) as TempArbiter,
    new SplitControlPowerManagerC() as PhotoPower,
    new SplitControlPowerManagerC() as TempPower,
    new PhotoTempControlP() as PhotoControl,
    new PhotoTempControlP() as TempControl,
    new TimerMilliC() as WarmupTimer,
    new AdcReadClientC() as Adc;

  PhotoResource = PhotoArbiter;
  PhotoPower.ResourceDefaultOwner -> PhotoArbiter;
  PhotoPower.ArbiterInfo -> PhotoArbiter;
  PhotoPower.SplitControl -> PhotoControl;
  PhotoControl.PhotoTempResource -> SharingArbiter.Resource[unique(UQ_PHOTOTEMP_RESOURCE)];
  PhotoControl.Timer -> WarmupTimer;
  PhotoControl.Power -> MicaBusC.Int1;
  ReadPhoto = PhotoControl;
  PhotoControl.ActualRead -> Adc;

  TempResource = TempArbiter;
  TempPower.ResourceDefaultOwner -> TempArbiter;
  TempPower.ArbiterInfo -> TempArbiter;
  TempPower.SplitControl -> TempControl;
  TempControl.PhotoTempResource -> SharingArbiter.Resource[unique(UQ_PHOTOTEMP_RESOURCE)];
  TempControl.Timer -> WarmupTimer;

// Tip to have Temperature value: http://www.keally.org/2008/11/26/tinyos-2x-getting-mts310-temperature-data/
//  TempControl.Power -> MicaBusC.Int2;
  TempControl.Power -> MicaBusC.PW0; 

  ReadTemp = TempControl;
  TempControl.ActualRead -> Adc;

  Adc.Atm128AdcConfig -> PhotoTempP;
  PhotoTempP.PhotoTempAdc -> MicaBusC.Adc1;
}
