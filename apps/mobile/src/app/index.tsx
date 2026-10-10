import { APP_NAME } from '@iitk-bicycle/shared';
import { StyleSheet, Text, View } from 'react-native';

export default function HomeScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>{APP_NAME}</Text>
      <Text style={styles.subtitle}>Campus bicycles, shared by everyone. Coming soon.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
    padding: 24,
    backgroundColor: '#ffffff',
  },
  title: {
    fontSize: 34,
    fontWeight: '600',
    color: '#11181C',
  },
  subtitle: {
    fontSize: 15,
    textAlign: 'center',
    color: '#5b6770',
  },
});
