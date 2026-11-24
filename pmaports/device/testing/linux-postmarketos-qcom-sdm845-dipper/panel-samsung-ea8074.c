// SPDX-License-Identifier: GPL-2.0-only
/*
 * Samsung EA8074 1080x2248 AMOLED DSI command-mode panel driver for the
 * Xiaomi Mi 8 (dipper / SDM845).
 *
 * Generated from Xiaomi's downstream kernel (Linux 4.9.186)
 *   arch/arm64/boot/dts/qcom/dsi-panel-ss-notch-fhd-ea8074-cmd.dtsi
 * by scripts/gen-panel-driver.py. Skeleton follows upstream
 * panel-samsung-ea8076.c from sdm845-mainline/linux sdm845/7.1-dev.
 *
 * VERIFY ON HARDWARE BEFORE USE. Wrong init sequences can damage a panel.
 */

#include <linux/backlight.h>
#include <linux/delay.h>
#include <linux/gpio/consumer.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>
#include <linux/workqueue.h>

#include <video/mipi_display.h>

#include <drm/drm_mipi_dsi.h>
#include <drm/drm_modes.h>
#include <drm/drm_panel.h>

struct samsung_ea8074 {
	struct drm_panel panel;
	struct mipi_dsi_device *dsi;
	struct gpio_desc *reset_gpio;
	struct regulator *vddio;
	struct regulator *vci;
	struct regulator *lab;
	struct regulator *ibb;
	struct delayed_work dcs_work;
};

static inline struct samsung_ea8074 *to_samsung_ea8074(struct drm_panel *panel)
{
	return container_of(panel, struct samsung_ea8074, panel);
}

static void samsung_ea8074_reset(struct samsung_ea8074 *ctx)
{
	/* Downstream dipper writes the sequence <1 1>, <0 1>, <1 10> with
	 * gpio_set_value(), i.e. those are PHYSICAL levels: high 1 ms, low
	 * 1 ms (the reset pulse), high 10 ms (run).
	 *
	 * reset-gpios is declared GPIO_ACTIVE_LOW in the DTS, so gpiod logical
	 * values are inverted: logical 0 = physical high = released,
	 * logical 1 = physical low = reset asserted.
	 *
	 * Up to r19 this function copied the downstream numbers verbatim,
	 * which on an active-low line means "asserted, released for 1 ms,
	 * asserted again" - the panel ended up held in reset for the whole
	 * init sequence. That is why every DCS write "succeeded" (writes are
	 * fire-and-forget) while the panel never answered a single read and
	 * never lit up. */
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);	/* release, physical high */
	usleep_range(1000, 2000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);	/* assert,  physical low  */
	usleep_range(1000, 2000);
	gpiod_set_value_cansleep(ctx->reset_gpio, 0);	/* release, physical high */
	usleep_range(10000, 11000);
}

static int samsung_ea8074_on(struct samsung_ea8074 *ctx)
{
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	ctx->dsi->mode_flags |= MIPI_DSI_MODE_LPM;

	mipi_dsi_dcs_exit_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x2b, 0x00, 0x00, 0x08, 0xc7);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xef, 0xf0, 0x31, 0x00, 0x33, 0x31, 0x14, 0x35);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x01);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xbb, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x4f);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xcb, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x6b);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xcb, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf7, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x05);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb1, 0x10);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x02);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd5, 0x02, 0x17, 0x54, 0x14);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xfc, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd2, 0x9f, 0xf0);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x0e);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd2, 0x70);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x04);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xd2, 0x20);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xfc, 0xa5, 0xa5);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x35, 0x00);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x51, 0x03, 0xff);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x53, 0x20);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0x55, 0x00);
	mipi_dsi_msleep(&dsi_ctx, 110);
	mipi_dsi_dcs_set_display_on_multi(&dsi_ctx);

	return dsi_ctx.accum_err;
}

static int samsung_ea8074_disable(struct drm_panel *panel)
{
	struct samsung_ea8074 *ctx = to_samsung_ea8074(panel);
	struct mipi_dsi_multi_context dsi_ctx = { .dsi = ctx->dsi };

	ctx->dsi->mode_flags &= ~MIPI_DSI_MODE_LPM;

	mipi_dsi_dcs_set_display_off_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 17);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0x5a, 0x5a);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x49);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xcb, 0xff);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xb0, 0x4f);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xcb, 0xc8);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf7, 0x03);
	mipi_dsi_dcs_write_seq_multi(&dsi_ctx, 0xf0, 0xa5, 0xa5);
	mipi_dsi_msleep(&dsi_ctx, 17);
	mipi_dsi_dcs_enter_sleep_mode_multi(&dsi_ctx);
	mipi_dsi_msleep(&dsi_ctx, 120);

	return dsi_ctx.accum_err;
}

/* r21: DCS read verification.
 *
 * Up to r19 this driver deliberately avoided mipi_dsi_dcs_read(): on hardware
 * it blocked the whole initramfs because the read channel never answered. That
 * turned out to be a symptom of the panel being held in reset (see
 * samsung_ea8074_reset()). Now that reset is correct the panel does answer, so
 * verify it - but from a delayed work 3 s after prepare(), so a wedged read can
 * never delay boot again.
 */
static void samsung_ea8074_dcs_check(struct work_struct *work)
{
	struct samsung_ea8074 *ctx = container_of(to_delayed_work(work),
						  struct samsung_ea8074,
						  dcs_work);
	struct device *dev = &ctx->dsi->dev;
	u8 power_mode = 0, diag = 0;
	int ret, ret2;

	ret = mipi_dsi_dcs_read(ctx->dsi, MIPI_DCS_GET_POWER_MODE,
				&power_mode, 1);
	ret2 = mipi_dsi_dcs_read(ctx->dsi, MIPI_DCS_GET_DIAGNOSTIC_RESULT,
				 &diag, 1);

	dev_info(dev, "EA8074: DCS read 0x0a=%d/0x%02x 0x0f=%d/0x%02x -> %s\n",
		 ret, power_mode, ret2, diag,
		 (ret < 0 || ret2 < 0) ? "DEAD" : "ALIVE");
	dev_info(dev, "EA8074: power mode bits: display_on=%d normal=%d sleep_out=%d\n",
		 !!(power_mode & BIT(2)), !!(power_mode & BIT(3)),
		 !!(power_mode & BIT(4)));
}

static int samsung_ea8074_prepare(struct drm_panel *panel)
{
	struct samsung_ea8074 *ctx = to_samsung_ea8074(panel);
	struct device *dev = &ctx->dsi->dev;
	int ret;

	if (ctx->vddio)
		regulator_enable(ctx->vddio);
	if (ctx->vci) {
		regulator_enable(ctx->vci);
		/* downstream panel supply entry: qcom,supply-post-on-sleep = <10> */
		usleep_range(10000, 11000);
	}
	if (ctx->lab)
		regulator_enable(ctx->lab);
	if (ctx->ibb)
		regulator_enable(ctx->ibb);

	samsung_ea8074_reset(ctx);

	ret = samsung_ea8074_on(ctx);
	if (ret < 0) {
		dev_err(dev, "Failed to initialize panel: %d\n", ret);
		gpiod_set_value_cansleep(ctx->reset_gpio, 1);
		return ret;
	}

	/* Writes above are fire-and-forget: accum_err == 0 only means "queued".
	 * The real proof that the panel is alive is a DCS read, scheduled from a
	 * delayed work so it cannot block boot (see samsung_ea8074_dcs_check). */
	dev_info(dev, "EA8074: init sequence done, mode_flags=0x%lx lanes=%d fmt=%d\n",
		 ctx->dsi->mode_flags, ctx->dsi->lanes, ctx->dsi->format);

	/* devm_backlight_device_register() does not push its initial brightness
	 * to the hardware on its own. Make sure the panel is actually lit when
	 * the DRM fbdev takes over from the bootloader's simple-framebuffer. */
	mipi_dsi_dcs_set_display_brightness_large(ctx->dsi, 1023);

	schedule_delayed_work(&ctx->dcs_work, msecs_to_jiffies(3000));

	return 0;
}

static int samsung_ea8074_unprepare(struct drm_panel *panel)
{
	struct samsung_ea8074 *ctx = to_samsung_ea8074(panel);

	cancel_delayed_work_sync(&ctx->dcs_work);

	/* ACTIVE_LOW reset line: logical 1 = physical low = panel held in
	 * reset while unpowered (the state probe() starts from). */
	gpiod_set_value_cansleep(ctx->reset_gpio, 1);
	if (ctx->ibb)
		regulator_disable(ctx->ibb);
	if (ctx->lab)
		regulator_disable(ctx->lab);
	if (ctx->vci) {
		/* downstream panel supply entry: qcom,supply-pre-off-sleep = <10> */
		usleep_range(10000, 11000);
		regulator_disable(ctx->vci);
	}
	if (ctx->vddio)
		regulator_disable(ctx->vddio);

	return 0;
}

static const struct drm_display_mode samsung_ea8074_mode = {
	/* 1080x2248 @ 60Hz, porches from downstream display timings */
	.clock = (1080 + 56 + 18 + 56) * (2248 + 26 + 12 + 24) * 60 / 1000,
	.hdisplay = 1080,
	.hsync_start = 1080 + 56,
	.hsync_end = 1080 + 56 + 18,
	.htotal = 1080 + 56 + 18 + 56,
	.vdisplay = 2248,
	.vsync_start = 2248 + 26,
	.vsync_end = 2248 + 26 + 12,
	.vtotal = 2248 + 26 + 12 + 24,
	.width_mm = 68,
	.height_mm = 142,
};

static int samsung_ea8074_get_modes(struct drm_panel *panel,
				     struct drm_connector *connector)
{
	struct drm_display_mode *mode;

	mode = drm_mode_duplicate(connector->dev, &samsung_ea8074_mode);
	if (!mode)
		return -ENOMEM;

	drm_mode_set_name(mode);
	mode->type = DRM_MODE_TYPE_DRIVER | DRM_MODE_TYPE_PREFERRED;
	connector->display_info.width_mm = mode->width_mm;
	connector->display_info.height_mm = mode->height_mm;
	drm_mode_probed_add(connector, mode);

	return 1;
}

static const struct drm_panel_funcs samsung_ea8074_panel_funcs = {
	.prepare = samsung_ea8074_prepare,
	.unprepare = samsung_ea8074_unprepare,
	.disable = samsung_ea8074_disable,
	.get_modes = samsung_ea8074_get_modes,
};

static int samsung_ea8074_bl_update_status(struct backlight_device *bl)
{
	struct mipi_dsi_device *dsi = bl_get_data(bl);
	u16 brightness = backlight_get_brightness(bl);

	/* EA8074 uses 10-bit DCS 0x51 brightness (0..1023). */
	return mipi_dsi_dcs_set_display_brightness_large(dsi, brightness);
}

static const struct backlight_ops samsung_ea8074_bl_ops = {
	.update_status = samsung_ea8074_bl_update_status,
};

static struct backlight_device *
samsung_ea8074_create_backlight(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	const struct backlight_properties props = {
		.type = BACKLIGHT_PLATFORM,
		.brightness = 1023,
		.max_brightness = 1023,
	};

	return devm_backlight_device_register(dev, dev_name(dev), dev, dsi,
					      &samsung_ea8074_bl_ops, &props);
}

static int samsung_ea8074_probe(struct mipi_dsi_device *dsi)
{
	struct device *dev = &dsi->dev;
	struct samsung_ea8074 *ctx;
	int ret;

	ctx = devm_kzalloc(dev, sizeof(*ctx), GFP_KERNEL);
	if (!ctx)
		return -ENOMEM;

	ctx->reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(ctx->reset_gpio))
		return dev_err_probe(dev, PTR_ERR(ctx->reset_gpio),
				     "Failed to get reset-gpios\n");

	ctx->vddio = devm_regulator_get_optional(dev, "vddio");
	if (IS_ERR(ctx->vddio))
		ctx->vddio = NULL;
	/* Downstream dipper panel pwr supply has TWO rails:
	 *   vddio 1.8 V (disp_vddio_vreg, GPIO 23)
	 *   vci   3.0 V (disp_vci_vreg, GPIO 35)
	 * Without vci the panel never powers up even though DSI clocks lock and
	 * the DPU keeps scanning frames (verified on hardware). */
	ctx->vci = devm_regulator_get_optional(dev, "vci");
	if (IS_ERR(ctx->vci))
		ctx->vci = NULL;
	/* Property names match sdm845-xiaomi-beryllium-common.dtsi's panel@0:
	 * vddio-supply / vddpos-supply / vddneg-supply */
	ctx->lab = devm_regulator_get_optional(dev, "vddpos");
	if (IS_ERR(ctx->lab))
		ctx->lab = NULL;
	ctx->ibb = devm_regulator_get_optional(dev, "vddneg");
	if (IS_ERR(ctx->ibb))
		ctx->ibb = NULL;

	ctx->dsi = dsi;
	mipi_dsi_set_drvdata(dsi, ctx);
	INIT_DELAYED_WORK(&ctx->dcs_work, samsung_ea8074_dcs_check);

	dsi->lanes = 4;
	dsi->format = MIPI_DSI_FMT_RGB888;
	/* Downstream is dsi_cmd_mode (qcom,mdss-dsi-panel-type in
	 * dsi-panel-ss-notch-fhd-ea8074-cmd.dtsi). Video mode was tried on
	 * hardware (r16) and is a dead end: this panel simply does not accept
	 * video streams. Stay in command mode. */
	dsi->mode_flags = MIPI_DSI_MODE_LPM | MIPI_DSI_CLOCK_NON_CONTINUOUS;

	drm_panel_init(&ctx->panel, dev, &samsung_ea8074_panel_funcs,
		       DRM_MODE_CONNECTOR_DSI);
	ctx->panel.prepare_prev_first = true;

	ctx->panel.backlight = samsung_ea8074_create_backlight(dsi);
	if (IS_ERR(ctx->panel.backlight))
		return dev_err_probe(dev, PTR_ERR(ctx->panel.backlight),
				     "Failed to create backlight\n");

	drm_panel_add(&ctx->panel);

	ret = mipi_dsi_attach(dsi);
	if (ret < 0) {
		drm_panel_remove(&ctx->panel);
		return dev_err_probe(dev, ret, "Failed to attach to DSI host\n");
	}

	return 0;
}

static void samsung_ea8074_remove(struct mipi_dsi_device *dsi)
{
	struct samsung_ea8074 *ctx = mipi_dsi_get_drvdata(dsi);
	int ret;

	cancel_delayed_work_sync(&ctx->dcs_work);

	ret = mipi_dsi_detach(dsi);
	if (ret < 0)
		dev_err(&dsi->dev, "Failed to detach from DSI host: %d\n", ret);

	drm_panel_remove(&ctx->panel);
}

static const struct of_device_id samsung_ea8074_of_match[] = {
	{ .compatible = "samsung,ea8074" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, samsung_ea8074_of_match);

static struct mipi_dsi_driver samsung_ea8074_driver = {
	.probe = samsung_ea8074_probe,
	.remove = samsung_ea8074_remove,
	.driver = {
		.name = "panel-samsung-ea8074",
		.of_match_table = samsung_ea8074_of_match,
	},
};
module_mipi_dsi_driver(samsung_ea8074_driver);

MODULE_AUTHOR("dipper Nura port");
MODULE_DESCRIPTION("Samsung EA8074 FHD+ AMOLED DSI command-mode panel (Xiaomi Mi 8)");
MODULE_LICENSE("GPL");
