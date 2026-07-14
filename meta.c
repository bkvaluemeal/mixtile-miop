#include <linux/module.h>

MODULE_LICENSE("GPL");

#ifdef EXPORT_REG_SYMBOLS
extern void miop_register_pcie_ep_drv(void);
extern void miop_register_ep_net_drv(void);
extern void miop_register_is_ready(void);

EXPORT_SYMBOL(miop_register_pcie_ep_drv);
EXPORT_SYMBOL(miop_register_ep_net_drv);
EXPORT_SYMBOL(miop_register_is_ready);
#endif
