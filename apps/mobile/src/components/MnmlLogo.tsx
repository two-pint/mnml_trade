import { View } from "react-native";
import Svg, { G, Path } from "react-native-svg";
import { useTheme } from "@/lib/theme-context";

interface MnmlLogoProps {
  height?: number;
  width?: number;
}

/** Logo from packages/ui (mnml_logo.svg / logo_light.svg); uses logo_light in dark mode */
export function MnmlLogo({ height = 40, width }: MnmlLogoProps) {
  const { isDark } = useTheme();
  const w = width ?? (height * 116.88) / 48.49;
  const textFill = isDark ? "#e4e4e7" : "#18181b";
  const frameFill = isDark ? "#e4e4e7" : "#18181b";

  return (
    <View style={{ height, width: w }}>
      <Svg viewBox="0 0 116.88 48.49" width="100%" height="100%">
        <G>
          <Path
            fill={textFill}
            d="M35.29,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z"
          />
          <Path
            fill={textFill}
            d="M57.83,11.65v25.2h-3.53l-13.32-18.83v18.83h-3.53V11.65h3.53l13.32,18.86V11.65h3.53Z"
          />
          <Path
            fill={textFill}
            d="M85.69,11.65v25.2h-3.53v-17.28l-7.81,17.28h-3.02l-7.81-17.28v17.28h-3.53V11.65h3.53l9.32,20.12,9.32-20.12h3.53Z"
          />
          <Path
            fill={textFill}
            d="M101.96,33.43v3.42h-14.11V11.65h3.53v21.78h10.58Z"
          />
          <Path fill="#059669" d="M103.76,32.45h3.53v4.39h-3.53v-4.39Z" />
        </G>
        <Path fill={frameFill} d="M116.88,48.49H0V0h116.88v48.49ZM4,44.49h108.88V4H4v40.49Z" />
      </Svg>
    </View>
  );
}
