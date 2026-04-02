import { View } from "react-native";
import Svg, { G, Path } from "react-native-svg";
import { useTheme } from "@/lib/theme-context";

interface MnmlLogoProps {
  height?: number;
  width?: number;
}

/** Same wordmark as @repo/ui Logo: logo_2 (light UI) / logo_light_1 (dark UI). */
const VIEWBOX = "0 0 250.89 64.7";
const PATHS = {
  text1: "M66,0v64.7h-9.06V20.34l-20.06,44.37h-7.76L9.06,20.34v44.37H0V0h9.06l23.94,51.67L56.94,0h9.06Z",
  text2: "M123.87,0v64.7h-9.06l-34.2-48.34v48.34h-9.06V0h9.06l34.2,48.44V0h9.06Z",
  text3: "M195.42,0v64.7h-9.06V20.34l-20.06,44.37h-7.76l-20.06-44.37v44.37h-9.06V0h9.06l23.94,51.67L186.36,0h9.06Z",
  text4: "M237.21,55.92v8.78h-36.23V0h9.06v55.92h27.18Z",
  dot: "M241.83,55.86h9.06v8.85h-9.06v-8.85Z",
} as const;

export function MnmlLogo({ height = 32, width }: MnmlLogoProps) {
  const { isDark } = useTheme();
  const textFill = isDark ? "#fafafa" : "#18181b";
  const w = width ?? (height * 250.89) / 64.7;

  return (
    <View style={{ height, width: w }}>
      <Svg viewBox={VIEWBOX} width="100%" height="100%">
        <G>
          <Path fill={textFill} d={PATHS.text1} />
          <Path fill={textFill} d={PATHS.text2} />
          <Path fill={textFill} d={PATHS.text3} />
          <Path fill={textFill} d={PATHS.text4} />
          <Path fill="#059669" d={PATHS.dot} />
        </G>
      </Svg>
    </View>
  );
}
